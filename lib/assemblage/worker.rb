# -*- ruby -*-
# frozen_string_literal: true

require 'fiber'
require 'state_machines'
require 'socket'
require 'cztop/reactor'
require 'cztop/reactor/signal_handling'

require 'assemblage' unless defined?( Assemblage )
require 'assemblage/auth'
require 'assemblage/mixins'


# A worker daemon that listens to the assembly server for assemblies to build
# and builds them.
class Assemblage::Worker
	extend Configurability,
	       Loggability,
	       Assemblage::MethodUtilities
	include CZTop::Reactor::SignalHandling,
	        Assemblage::SocketMonitorLogging

	# The list of signals the worker responds to
	HANDLED_SIGNALS = %i[TERM HUP INT] & Signal.list.keys.map( &:to_sym )

	# The name given to workers by default
	DEFAULT_WORKER_NAME = "#{Socket.gethostname.gsub('.', '-').downcase}-worker1"

	# The list of valid actions for a worker
	HANDLED_MESSAGE_TYPES = %i[hello goodbye new_assembly]

	# The time between checks for new assemblies to work on
	ASSEMBLY_TIMER_INTERVAL = 5.seconds


	# Loggability API -- log to the Assemblage logger.
	log_to :assemblage


	### Returns +true+ if the specified +name+ is valid for a worker's name.
	def self::valid_worker_name?( name )
		return Assemblage::Auth.valid_client_name?( name )
	end


	# Configurability API -- declare some settings for Workers.
	configurability( 'assemblage.worker' ) do

		##
		# The name the worker uses to identify itself
		setting :name, default: DEFAULT_WORKER_NAME do |name|
			raise ArgumentError, "invalid worker name %p" % [ name ] unless
				Assemblage::Worker.valid_worker_name?( name )
			name
		end


		##
		# The tags the worker uses to advertise the capabilities of its local
		# environment.
		setting :tags, default: [] do |tags|
			Array( tags )
		end


		##
		# The assembly server the worker will listen to for work.
		setting :server

	end


	state_machine( :status, initial: :unstarted ) do

		state :unstarted,
			:connecting,
			:waiting,
			:working,
			:stopping

		event :on_hello_message do
			transition :connecting => :waiting
		end

		event :on_new_assembly_message do
			transition :waiting => :working
		end

		event :on_assembly_finished do
			transition :working => :waiting, if: :assembly_queue_empty?
		end

		event :on_goodbye_message do
			transition :waiting => :connecting
		end

		event :stop do
			transition any => :stopping
		end


		after_transition any => any, do: :log_transition

		after_transition :connecting => :waiting, do: :start_status_report_timer
		after_transition [:waiting, :working] => :stopping, do: :stop_status_report_timer
		after_transition [:waiting, :working] => :stopping, do: :send_goodbye
		after_transition any - [:stopping] => :stopping, do: :shutdown

		after_failure do: :log_transition_failure
	end


	### Generate a client CZTop::Certificate for the worker.
	def self::generate_cert
		Assemblage::Auth.generate_local_cert unless Assemblage::Auth.has_local_cert?
	end


	### Return the worker's public key as a Z85-encoded ASCII string.
	def self::public_key
		return Assemblage::Auth.local_cert.public_key
	end


	### Set up the Worker's directory as a worker run directory. Raises an
	### exception if the directory already exists and is not empty.
	def self::setup_run_directory( directory='.', name=DEFAULT_WORKER_NAME, tags=[] )
		directory = Pathname( directory || '.' )
		raise "Directory not empty" if directory.exist? && !directory.empty?

		self.log.debug "Attempting to set up %s as a run directory." % [ directory ]
		directory.mkpath
		directory.chmod( 0755 )

		config = Assemblage.config || Configurability.default_config
		config.assemblage.auth.cert_store_dir ||= (directory + 'certs').to_s
		config.assemblage.worker.name = name
		config.assemblage.worker.tags = tags

		Loggability.with_level( :fatal ) do
			config.install
		end
		config.write( directory + Assemblage::DEFAULT_CONFIG_FILE )
	end


	### Add a new server at the given +url+ to the current run directory.
	def self::add_server( url, public_key )
		config = Assemblage.config

		if config&.path
			self.log.debug "Writing server config to %s" % [ config.path ]
			config.assemblage.worker.server = url
			config.write
		else
			self.log.warn "Couldn't write server URL to the config: not loaded from a file!"
		end

		# :TODO: Change this when/if workers support listening to multiple servers.
		name = 'server'
		Assemblage::Auth.save_remote_cert( name, public_key )
	end


	### Run an instance of the worker from the specified +run_directory+.
	def self::run( run_directory=nil, **options )
		Assemblage.use_run_directory( run_directory, reload_config: true )
		return self.new( **options ).run
	end


	#
	# Instance methods
	#

	### Create a nwe Assemblage::Worker.
	def initialize( name: nil, server: nil, tags: nil )
		@name       = name || Assemblage::Worker.name or raise "No worker name specified."
		@server     = server || Assemblage::Worker.server or raise "No server specified."
		@tags       = Array( tags || Assemblage::Worker.tags )
		@reactor    = CZTop::Reactor.new
		@socket     = nil
		@start_time = nil

		@assembly_builders   = []
		@send_queue          = []
		@status_report_timer = nil
	end


	######
	public
	######


	##
	# The client name associated with the worker
	attr_reader :name

	##
	# The URL for the server the worker will accept assemblies from
	attr_reader :server

	##
	# The CZTop::Reactor that handles asynchronous IO, timed events, and signals.
	attr_reader :reactor

	##
	# The CZTop::Socket::SERVER the server uses for communication with repos and workers.
	attr_reader :socket

	##
	# The Time the worker started
	attr_accessor :start_time

	##
	# The Assemblage::AssemblyBuilders that have been created for pending
	# assemblies.
	attr_accessor :assembly_builders

	##
	# The queue of assembly reports the worker has yet to report back to the server
	attr_reader :report_queue


	### Run the server.
	def run
		Assemblage::Auth.check_environment
		self.log.info "Starting assembly worker '%s'." % [ self.name ]

		@socket = self.create_client_socket
		self.reactor.register( @socket, :read, &self.method(:on_socket_event) )

		self.start_assembly_timer

		self.log.debug "Starting event loop."
		self.with_signal_handler( self.reactor, *HANDLED_SIGNALS ) do
			@start_time = Time.now
			self.reactor.start_polling( ignore_interrupts: true )
		end
		@start_time = null
		self.log.debug "Exited event loop."
	end


	### Stop the worker.
	def stop
		self.log.info "Stopping the assembly worker."
		self.reactor.stop_polling
		self.monitor.terminate if self.monitor
	end


	### Returns +true+ if the server is *not* running.
	def stopped?
		return ! self.running?
	end


	### Return the CLIENT socket that's used to connect to the assembly server.
	def create_client_socket
		self.log.debug "Creating a CLIENT socket bound to: %s" % [ self.server ]
		sock = CZTop::Socket::CLIENT.new

		client_cert = Assemblage::Auth.local_cert
		server_cert = Assemblage::Auth.remote_cert( 'server' )

		self.log.debug "Connecting with %p and %p" % [ client_cert, server_cert ]
		sock.CURVE_client!( client_cert, server_cert )
		sock.connect( self.server )

		return sock
	end


	### Periodically check for new assemblies to work on. If there are some, start
	### working on them.
	def start_assembly_timer
		self.reactor.
			add_periodic_timer( ASSEMBLY_TIMER_INTERVAL, &self.method(:work_on_assemblies) )
	end


	### Return the AssemblyBuilder that is currently working, if any.
	def current_assembly_builder
		return self.assembly_builders.first
	end


	### Start the next assembly if there is one and the worker is idle.
	def work_on_assemblies
		builder = self.current_assembly_builder or return # No builders queued
		result = builder.resume

		if result
			self.log.info "Builder finished; queueing result."
			self.on_assembly_finished( builder, result )
		else
			self.log.debug "Building still working."
		end
	end


	### Notify the worker that the assembly being built by the specified +builder+
	### has finished with the given +result+.
	def on_assembly_finished( builder, result )
		self.send_result( builder.assembly_id, result )
		super
	end


	### Start the timer that periodically reports on the worker's status to the
	### server/s it's connected to.
	def start_status_report_timer
		@status_report_timer = self.reactor.
			add_periodic_timer( STATUS_REPORT_INTERVAL, &self.method(:send_status_report) )
	end


	### Stop the timer that periodically reports on the worker's status.
	def stop_status_report_timer
		self.reactor.remove_timer( @status_report_timer )
	end


	### Return the number of seconds the worker has been running.
	def uptime
		return Time.now - self.start_time
	end


	### Queue a status report message for the worker.
	def send_status_report
		report = {
			version: Assemblage::VERSION,
			status: self.status,
			uptime: self.uptime
		}

		message = Assemblage::Protocol.encode( :status_report, report )

		self.send_message( message )
	end


	### Queue a result message for the worker.
	def send_result( assembly_id, result )
		message = Assemblage::Protocol.encode( :result, assembly_id, result )
		self.send_message( message )
	end


	### Queue up the specified +message+ for sending to the server.
	def send_message( message )
		self.send_queue << message
		self.reactor.enable_events( self.socket, :write ) unless
			self.reactor.event_enabled?( self.socket, :write )
	end


	### Handle an event on the CLIENT socket.
	def on_socket_event( event )
		if event.readable?
			self.handle_readable_io_event( event )
		elsif event.writable?
			self.handle_writable_io_event( event )
		else
			raise "Socket event was neither readable nor writable!? (%p)" % [ event ]
		end
	end


	### Handle a readable event on a socket.
	def handle_readable_io_event( event )
		self.log.debug "Got socket read event: %p" % [ event ]
		msg = event.socket.receive
		type, data, header = Assemblage::Protocol.decode( msg )

		unless HANDLED_MESSAGE_TYPES.include?( type )
			self.log.error "Got unhandled message type %p" % [ type ]
			raise "Invalid action %p!" % [ type ]
		end

		method_name = "on_%s_message" % [ type ]
		handler = self.method( method_name )
		handler.call( data, header )
	end


	### Handle the socket becoming writable by sending the next queued message to the hub and
	### unregistered it from writable events if that empties the queue.
	def handle_writable_io_event( event )
		if message = self.send_queue.shift
			message.send_to( self.socket )
		else
			self.reactor.disable_events( self.socket, :write )
		end
	end


	### Handle a +signal+ trapped by the reactor.
	def handle_signal( signal )
		self.log.info "Handling %p signal." % [ signal ]
		case signal
		when :INT, :TERM, :HUP
			self.stop
		else
			super
		end
	end


	### Handle a `hello` message from the server.
	def on_hello_message( info, * )
		self.log.info "Connected. Waiting for an assembly to build."
		super
	end


	### Handle a `new_assembly` message from the server.
	def on_new_assembly_message( assembly, * )
		self.log.info "Creating a new builder for: %p" % [ assembly ]
		builder = Assemblage::AssemblyBuilder.new( assembly )
		builder.start

		self.builder_queue << builder

		super
	end

end # class Assemblage::Worker

