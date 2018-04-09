# -*- ruby -*-
# frozen_string_literal: true

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


	### Test the given +public_key+ with a connection to the given +url+. Raise an
	### exception if there is a problem.
	def self::test_connection( url )
		instance = new( server: url )
	end


	### Add a new server at the given +url+ to the current run directory.
	def self::add_server( url, public_key )
		config = Assemblage.config
		if config.path
			config.assemblage.worker.server = url
			config.write
		end

		# :TODO: Change this when/if workers support listening to multiple servers.
		name = 'server'
		Assemblage::Auth.save_remote_cert( name, public_key )
	end


	### Run an instance of the worker from the specified +run_directory+.
	def self::run( run_directory=nil, **options )
		Assemblage.use_run_directory( run_directory )
		return self.new( **options ).run
	end


	#
	# Instance methods
	#

	### Create a nwe Assemblage::Worker.
	def initialize( name: nil, server: nil, tags: nil )
		@name    = name || Assemblage::Worker.name or raise "No worker name specified."
		@server  = server || Assemblage::Worker.server or raise "No server specified."
		@tags    = Array( tags || Assemblage::Worker.tags )
		@reactor = CZTop::Reactor.new
		@socket  = nil
		@running = false
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
	# True if the server is running
	attr_predicate :running


	### Run the server.
	def run
		Assemblage::Auth.check_environment
		self.log.info "Starting assembly worker '%s'." % [ self.name ]

		@socket = self.create_client_socket
		self.reactor.register( @socket, :read, &self.method(:on_socket_event) )

		self.log.debug "Starting event loop."
		self.with_signal_handler( self.reactor, *HANDLED_SIGNALS ) do
			@running = true
			self.reactor.start_polling( ignore_interrupts: true )
		end
		@running = false
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


	### Handle an event on the CLIENT socket.
	def on_socket_event( event )
		self.log.debug "Got socket event: %p" % [ event ]
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

end # class Assemblage::Worker

