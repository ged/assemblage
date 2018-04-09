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
		Assemblage.use_run_directory( run_directory )
		return self.new( **options ).run
	end


	#
	# Instance methods
	#

	### Create a new Assemblage::Server.
	def initialize( endpoint: nil )
		@endpoint  = endpoint || Assemblage::Server.endpoint
		@reactor   = CZTop::Reactor.new
		@socket    = nil
		@monitor   = nil
		@running   = false
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
	# True if the server is running
	attr_predicate :running


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
			@running = true
			self.reactor.start_polling( ignore_interrupts: true )
		end
		@running = false
		self.log.debug "Exited event loop."
	end


	### Stop the server.
	def stop
		self.log.info "Stopping the assembly server."
		self.reactor.stop_polling
		self.monitor.terminate if self.monitor
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


	#########
	protected
	#########

	### Return the SERVER socket that handles connections from repository event hooks and
	### workers, creating and binding it first if necessary.
	def create_server_socket
		self.log.debug "Creating a SERVER socket bound to: %s" % [ endpoint ]
		sock = CZTop::Socket::SERVER.new

		sock.CURVE_server!( Assemblage::Auth.local_cert )
		sock.options.heartbeat_ivl     = self.class.heartbeat_interval
		sock.options.heartbeat_timeout = self.class.heartbeat_timeout
		sock.options.zap_domain        = ZAP_DOMAIN

		sock.bind( self.endpoint )

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
		message = event.socket.receive
		frame = message.frames.first # CLIENT/SERVER can't be multipart
		clientname = frame.meta( 'clientname' )

		type, data, header = Assemblage::Protocol.decode( frame )

		self.log.debug "Got message %p from %p" % [ frame.to_a, clientname ]
	end


	### Dequeue a message from the output queue and route it to the appropriate user.
	def handle_client_output( event )
		self.log.debug "Socket was writable."
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

