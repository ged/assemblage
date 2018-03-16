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
	include CZTop::Reactor::SignalHandling


	# The list of signals the server responds to
	HANDLED_SIGNALS = %i[TERM HUP INT] & Signal.list.keys.map( &:to_sym )


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
		# The ZMQ endpoint to use when connecting to the server.
		setting :endpoint, default: 'tcp://127.0.0.1:*'

	end



	### Create a new Assemblage::Server that will run in the specified +directory+.
	def initialize( directory='.' )
		@directory = Pathname( directory || '.' ).expand_path
		@reactor   = CZTop::Reactor.new
		@socket    = nil
		@thread    = nil
		@monitor   = nil
		@running   = false
	end


	######
	public
	######

	##
	# The Pathname of the Server's run directory.
	attr_reader :directory

	##
	# The CZTop::Reactor that handles asynchronous IO, timed events, and signals.
	attr_reader :reactor

	##
	# The CZTop::Socket::SERVER the server uses for communication with repos and workers.
	attr_reader :socket

	##
	# The Thread of the running server (if it's running)
	attr_reader :thread

	##
	# The CZTop::Monitor for the server socket
	attr_reader :monitor

	##
	# True if the server is running
	attr_predicate :running


	### Start the server.
	def start
		self.log.info "Starting assembly server."
		Assemblage::Auth.check_environment
		Assemblage::Auth.authenticator.verbose! #if $DEBUG

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


	### If the server's socket is bound, return the endpoint it's listening on.
	def endpoint
		return self.socket&.last_endpoint
	end


	### Returns +true+ if the server is *not* running.
	def stopped?
		return ! self.running?
	end


	### Set up the Server's directory as an Assemblage run directory. Raises an
	### exception if the directory already exists and is not empty.
	def setup_run_directory
		raise "Directory not empty" if self.directory.exist? && !self.directory.empty?

		self.log.debug "Attempting to set up %s as a run directory." % [ self.directory ]
		self.directory.mkpath
		self.directory.chmod( 0755 )

		config = Assemblage.config || Configurability.default_config
		config.assemblage.directory = self.directory.to_s
		config.assemblage.auth.cert_store_dir ||= (self.directory + 'certs').to_s
		config.assemblage.db.uri = "sqlite:%s" % [ self.directory + 'assemblage.db' ]

		config.write( self.directory + Assemblage::DEFAULT_CONFIG_FILE.basename )

		config.install
	end


	### Generate a new server cert/keypair for authentication.
	def generate_cert
		Assemblage::Auth.generate_server_cert unless Assemblage::Auth.has_server_cert?
	end


	### Return the server's public key as a Z85-encoded ASCII string.
	def public_key
		return Assemblage::Auth.server_cert.public_key
	end


	### Create the database the assembly information is tracked in.
	def create_database
		Assemblage::DbObject.setup_database unless Assemblage::DbObject.database_is_current?
	end


	#########
	protected
	#########

	### Return the SERVER socket that handles connections from repository event hooks and
	### workers, creating and binding it first if necessary.
	def create_server_socket
		self.log.debug "Creating a SERVER socket bound to: %s" % [ endpoint ]
		sock = CZTop::Socket::SERVER.new( endpoint )

		sock.CURVE_server!( Assemblage::Auth.server_cert )
		sock.options.heartbeat_ivl     = self.class.heartbeat_interval
		sock.options.heartbeat_timeout = self.class.heartbeat_timeout
		sock.options.zap_domain        = 'FaerieMUD'

		sock.bind( self.class.endpoint )

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

		self.log.debug "Got message %p from %p" % [ frame.to_a, frame.meta('clientname') ]
	end


	### Dequeue a message from the output queue and route it to the appropriate user.
	def handle_client_output( event )
		self.log.debug "Socket was writable."
	end


	### Handle events from the SERVER socket's monitor.
	def on_monitor_event( poll_event )
		self.log.debug "Got monitor event: %p" % [ poll_event ]

		msg = poll_event.socket.receive
		type, *payload = *msg
		callback_name = "on_#{type.downcase}"

		if self.respond_to?( callback_name, true )
			self.send( callback_name, *payload )
		else
			self.log.warn "No handler (#%s) for monitored %s event." % [ callback_name, type ]
		end
	end


	### Monitor event callback for socket connection events
	def on_connected( fd, endpoint )
		self.log.debug "Client socket on FD %d connected" % [ fd ]
		self.publish( 'socket/connected', fd, endpoint )
	end


	### Monitor event callback for socket accepted events
	def on_accepted( fd, endpoint )
		self.log.debug "Client socket on FD %d accepted" % [ fd ]
		self.publish( 'socket/accepted', fd, endpoint )
	end


	### Monitor event callback for successful auth events.
	def on_handshake_succeed( fd, endpoint )
		self.log.debug "Client socket on FD %d handshake succeeded" % [ fd ]
		self.publish( 'socket/auth/success', fd, endpoint )
	end


	### Monitor event callback for failed auth events.
	def on_handshake_failed( fd, endpoint )
		self.log.debug "Client socket on FD %d handshake failed" % [ fd ]
		self.publish( 'socket/auth/failure', fd, endpoint )
	end


	### Monitor event callback for socket closed events
	def on_closed( fd, endpoint )
		self.log.debug "Client socket on FD %d closed" % [ fd ]
		self.publish( 'socket/closed', fd, endpoint )
	end


	### Monitor event callback for socket disconnection events
	def on_disconnected( fd, endpoint )
		self.log.debug "Client socket on FD %d disconnected" % [ fd ]
		self.publish( 'socket/disconnected', fd, endpoint )
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

