# -*- ruby -*-
# frozen_string_literal: true

require 'cztop/reactor'
require 'cztop/reactor/signal_handling'
require 'configurability'
require 'loggability'
require 'pathname'

require 'assemblage' unless defined?( Assemblage )
require 'assemblage/auth'
require 'assemblage/db_object'
require 'assemblage/mixins'


# The Assembly server.
#
# This gathers events from repositories and dispatches them to workers via one
# or more "assemblies". An assembly is the combination of a repository and one
# or more tags that describe pre-requisites for building a particular product.
class Assemblage::Server
	extend Loggability,
	       Configurability,
	       Assemblage::MethodUtilities
	include CZTop::Reactor::SignalHandling,
	        Assemblage::SocketMonitorLogging

	# The list of signals the server responds to
	HANDLED_SIGNALS = %i[TERM HUP INT] & Signal.list.keys.map( &:to_sym )

	# The ZAP authentication domain the server will use
	ZAP_DOMAIN = 'assemblage'

	# The list of valid commands for clients
	VALID_COMMANDS = %i[
		status
		status_report
	]


	# Log to the Assemblage logger
	log_to :assemblage


	configurability( 'assemblage.server' ) do

		##
		# :singleton-method:
		# Configurable: The number of milliseconds between heartbeats on the server's socket
		setting :heartbeat_interval, default: 100

		##
		# :singleton-method:
		# Configurable: The number of milliseconds without a heartbeat to wait before timing
		# out a connection on the server socket.
		setting :heartbeat_timeout, default: 300

		##
		# :singleton-method:
		# The default ZMQ endpoint to listen on for connections from clients and repos
		setting :endpoint, default: 'tcp://127.0.0.1:*'

	end


	### Set up the Server's directory as an Assemblage run directory. Raises an
	### exception if the directory already exists and is not empty.
	def self::setup_run_directory( directory )
		directory = Pathname( directory )

		raise "Directory not empty" if directory.exist? && !directory.empty?

		self.log.debug "Attempting to set up %s as a run directory." % [ directory ]
		directory.mkpath
		directory.chmod( 0755 )

		config = Assemblage.config || Configurability.default_config
		config.assemblage.auth.cert_store_dir ||= (directory + 'certs').to_s
		config.assemblage.db.uri = "sqlite:%s" % [ directory + 'assemblage.db' ]

		config.install
		config.write( directory + Assemblage::DEFAULT_CONFIG_FILE )
	end


	### Generate a new server cert/keypair for authentication.
	def self::generate_cert
		Assemblage::Auth.generate_local_cert unless Assemblage::Auth.has_local_cert?
	end


	### Return the server's public key as a Z85-encoded ASCII string.
	def self::public_key
		return Assemblage::Auth.local_cert.public_key
	end


	### Create the database the assembly information is tracked in.
	def self::create_database
		Assemblage::DbObject.setup_database unless Assemblage::DbObject.database_is_current?
	end


	### Add a worker with the specified +name+ and +public_key+ to the current run
	### directory.
	def self::add_worker( name, public_key )
		cert = Assemblage::Auth.save_remote_cert( name, public_key )
		client = Assemblage::Client.create( name: name, type: 'worker' )

		return client.id
	end


	### Run an instance of the server from the specified +run_directory+.
	def self::run( run_directory=nil, **options )
		Assemblage.use_run_directory( run_directory, reload_config: true )
		return self.new( **options ).run
	end


	#
	# Instance methods
	#

	### Create a new Assemblage::Server.
	def initialize( endpoint: nil )
		@endpoint     = endpoint || Assemblage::Server.endpoint

		@reactor      = CZTop::Reactor.new
		@socket       = nil
		@monitor      = nil
		@clients      = {}
		@output_queue = []
		@start_time   = nil
	end


	######
	public
	######

	##
	# The endpoint to listen on for connections from workers and repos.
	attr_reader :endpoint

	##
	# The CZTop::Reactor that handles asynchronous IO, timed events, and signals.
	attr_reader :reactor

	##
	# The CZTop::Socket::SERVER the server uses for communication with repos and workers.
	attr_reader :socket

	##
	# The CZTop::Monitor for the server socket
	attr_reader :monitor

	##
	# The Hash of connected Assemblage::Clients, keyed by their routing ID
	attr_reader :clients

	##
	# The queue of outgoing messages which are waiting for the socket to become writable.
	attr_reader :output_queue

	##
	# The time the server started up.
	attr_reader :start_time


	### Run the server.
	def run
		Assemblage::Auth.check_environment
		self.log.info "Starting assembly server."

		Assemblage::Auth.authenticator.verbose! if $DEBUG

		@socket = self.create_server_socket
		self.reactor.register( @socket, :read, &self.method(:on_socket_event) )
		@monitor = self.reactor.register_monitor( @socket, &self.method(:on_monitor_event) )

		self.log.debug "Starting event loop."
		self.with_signal_handler( self.reactor, *HANDLED_SIGNALS ) do
			@start_time = Time.now
			self.reactor.start_polling( ignore_interrupts: true )
		end
		@start_time = nil
		self.log.debug "Exited event loop."
	end


	### Stop the server.
	def stop
		self.log.info "Stopping the assembly server."
		self.reactor.stop_polling
		self.monitor.terminate if self.monitor
	end


	### Returns +true+ if the server is running.
	def running?
		return ! self.start_time.nil?
	end


	### Returns +true+ if the server is *not* running.
	def stopped?
		return ! self.running?
	end


	### If the server's socket is bound, return the endpoint it's listening on. This
	### can be different than #endpoint if the specified endpoint is ephemeral.
	def last_endpoint
		return self.socket&.last_endpoint
	end


	### Return the number of seconds the server has been running if it is. Returns
	### +nil+ otherwise.
	def uptime
		return (Time.now - self.start_time)
	end


	#
	# Command methods
	#

	### Handle a `status` command for the specified +client+.
	def handle_status_command( client, * )
		status = { version: Assemblage::VERSION, uptime: self.uptime }
		self.queue_output_message( client.make_response(:status, status) )
	end


	### Handle a client sending a status report.
	def handle_status_report_command( client, report, * )
		self.log.debug "Client %s sent a status report: %p" % [ report ]
	end


	#########
	protected
	#########

	### Return the SERVER socket that handles connections from repository event hooks and
	### workers, creating and binding it first if necessary.
	def create_server_socket
		self.log.info "Creating a SERVER socket bound to: %s" % [ endpoint ]
		sock = CZTop::Socket::SERVER.new

		sock.CURVE_server!( Assemblage::Auth.local_cert )
		sock.options.heartbeat_ivl     = self.class.heartbeat_interval
		sock.options.heartbeat_timeout = self.class.heartbeat_timeout
		sock.options.zap_domain        = ZAP_DOMAIN

		sock.bind( self.endpoint )
		self.log.info "Bound to %s" % [ sock.last_endpoint ]

		return sock
	end


	### Handle incoming read events from connected/authed clients.
	def on_socket_event( event )
		if event.readable?
			self.handle_client_input( event )
		elsif event.writable?
			self.handle_client_output( event )
		else
			raise "Socket event was neither readable nor writable!? (%s)" % [ event ]
		end
	end


	### Read a message from a user and route it to their Client.
	def handle_client_input( event )
		raise "Server is shutting down" unless self.running?

		message = event.socket.receive
		frame = message.frames.first

		if (( client = self.client_for_sender(frame) ))
			command = Assemblage::Protocol.decode( message )
			self.handle_command( client, *command )
		else
			self.log.error "Read event from an unknown origin: routing_id: %p, clientname: %p" %
				[ frame.routing_id, frame.meta('clientname') ]
		end
	end


	### Dequeue a message from the output queue and route it to the appropriate client.
	def handle_client_output( event )
		message = self.output_queue.shift
		message.send_to( event.socket )
	rescue IO::EAGAINWaitWritable => err
		self.log.info "send timeout writing to RID %d: requeuing" % [ message.routing_id ]
		self.output_queue.unshift( message )
	rescue SocketError => err
		self.log.error "%p when writing to RID %d: %s" %
			[ err.class, message.routing_id, err.message ]
	ensure
		self.unregister_for_writing if self.output_queue.empty?
	end


	### Handle the specified +command+ triple for +client+. The +command+ should be an Array
	### of a command type (a Symbol), any data associated with the command, and a header Hash.
	def handle_command( client, command, data, header )
		raise "Invalid command %p" % [ command ] unless VALID_COMMANDS.include?( command )

		method_name = "handle_%s_command" % [ command ]
		callable = self.method( method_name )
		callable.call( client, data, header )

	rescue => err
		self.log.error "%p while handling command: %s" % [ err.class, err.message ]
		self.queue_output_message( client.make_error_response(err) )
	end


	### Queue the given +message+ for output on the server socket.
	def queue_output_message( message )
		self.output_queue << message
		self.register_for_writing
	end


	### Start watching for the SERVER socket to become writable when there's output
	### to send.
	def register_for_writing
		self.reactor.enable_socket_events( self.socket, :write ) unless
			self.reactor.socket_event_enabled?( self.socket, :write )
	end


	### Stop watching for the SERVER socket to become writable when there's no
	### output left to send.
	def unregister_for_writing
		self.reactor.disable_socket_events( self.socket, :write ) if
			self.reactor.socket_event_enabled?( self.socket, :write )
	end


	### Find the client associated with the specified message +frame+ (a
	### CZTop::Frame), creating a new one if this is the first message from them.
	def client_for_sender( frame )
		rid = frame.routing_id
		return self.clients.fetch( rid ) do
			clientname = frame.meta( 'clientname' )
			self.connect_client( clientname, rid )
		end
	end


	### Look up the client associated with the specified +clientname+, connect it to
	### the manager via the given +routing_id+, and return it.
	def connect_client( clientname, routing_id )
		self.log.debug "Looking up client: %s" % [ clientname ]

		client = Assemblage::Client[ name: clientname ] or return nil
		client.on_connected( self, routing_id )
		self.clients[ routing_id ] = client

		return client
	end


	### Disconnect the specified +client+.
	def disconnect_client( client )
		self.log.info "Dropping connection for client '%s'" % [ client.name ]
		routing_id = client.routing_id

		client.on_disconnected

		message = Assemblage::Protocol.encode( :control, [:disconnect] )
		message.routing_id = routing_id
		self.queue_output_message( message )

		self.log.debug "  deleting %p from: %p" % [ routing_id, self.clients ]
		self.clients.delete( routing_id )
		self.log.debug "  disconnected (%d client/s remain)." % [ self.clients.length ]
	end


	### Disconnect all currently-connected clients.
	def disconnect_all_clients
		self.log.info "Disconnecting %d client/s." % [ self.clients.length ]
		self.clients.values.each do |client|
			self.disconnect_client( client )
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

end # class Assemblage::Server

