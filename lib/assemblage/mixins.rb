# -*- ruby -*-
# frozen_string_literal: true

# A collection of generically-useful mixins
module Assemblage

	# A collection of methods for declaring other methods.
	#
	#   class MyClass
	#       extend Assemblage::MethodUtilities
	#
	#       singleton_attr_accessor :types
	#       singleton_method_alias :kinds, :types
	#   end
	#
	#   MyClass.types = [ :pheno, :proto, :stereo ]
	#   MyClass.kinds # => [:pheno, :proto, :stereo]
	#
	module MethodUtilities

		### Creates instance variables and corresponding methods that return their
		### values for each of the specified +symbols+ in the singleton of the
		### declaring object (e.g., class instance variables and methods if declared
		### in a Class).
		def singleton_attr_reader( *symbols )
			singleton_class.instance_exec( symbols ) do |attrs|
				attr_reader( *attrs )
			end
		end

		### Create instance variables and corresponding methods that return
		### true or false values for each of the specified +symbols+ in the singleton
		### of the declaring object.
		def singleton_predicate_reader( *symbols )
			singleton_class.extend( Assemblage::MethodUtilities )
			singleton_class.attr_predicate( *symbols )
		end

		### Creates methods that allow assignment to the attributes of the singleton
		### of the declaring object that correspond to the specified +symbols+.
		def singleton_attr_writer( *symbols )
			singleton_class.instance_exec( symbols ) do |attrs|
				attr_writer( *attrs )
			end
		end

		### Creates readers and writers that allow assignment to the attributes of
		### the singleton of the declaring object that correspond to the specified
		### +symbols+.
		def singleton_attr_accessor( *symbols )
			symbols.each do |sym|
				singleton_class.__send__( :attr_accessor, sym )
			end
		end

		### Create predicate methods and writers that allow assignment to the attributes
		### of the singleton of the declaring object that correspond to the specified
		### +symbols+.
		def singleton_predicate_accessor( *symbols )
			singleton_class.extend( Assemblage::MethodUtilities )
			singleton_class.attr_predicate_accessor( *symbols )
		end

		### Creates an alias for the +original+ method named +newname+.
		def singleton_method_alias( newname, original )
			singleton_class.__send__( :alias_method, newname, original )
		end


		### Create a reader in the form of a predicate for the given +attrname+.
		def attr_predicate( attrname )
			attrname = attrname.to_s.chomp( '?' )
			define_method( "#{attrname}?" ) do
				instance_variable_get( "@#{attrname}" ) ? true : false
			end
		end


		### Create a reader in the form of a predicate for the given +attrname+
		### as well as a regular writer method.
		def attr_predicate_accessor( attrname )
			attrname = attrname.to_s.chomp( '?' )
			attr_writer( attrname )
			attr_predicate( attrname )
		end


		### Create an method that is both a reader and a writer for an instance
		### variable. If called with a (non-nil) argument, it will set the variable to
		### the new value. It returns whatever the instance variable is set to.
		def dsl_accessor( attrname )
			define_method( attrname ) do |arg=nil|
				instance_variable_set( "@#{attrname}", arg ) unless arg.nil?
				return instance_variable_get( "@#{attrname}" )
			end
		end

	end # module MethodUtilities



	# A collection of miscellaneous functions that are useful for manipulating
	# complex data structures.
	#
	#   include Assemblage::DataUtilities
	#   newhash = deep_copy( oldhash )
	#
	module DataUtilities

		###############
		module_function
		###############

		### Recursively copy the specified +obj+ and return the result.
		def deep_copy( obj )

			# Handle mocks during testing
			return obj if obj.class.name == 'RSpec::Mocks::Mock'

			return case obj
				when NilClass, Numeric, TrueClass, FalseClass, Symbol,
				     Module, Encoding, IO, Tempfile
					obj

				when Array
					obj.map {|o| deep_copy(o) }

				when Hash
					newhash = {}
					newhash.default_proc = obj.default_proc if obj.default_proc
					obj.each do |k,v|
						newhash[ deep_copy(k) ] = deep_copy( v )
					end
					newhash

				else
					obj.clone
				end
		end


		### Create and return a Hash that will auto-vivify any values it is missing with
		### another auto-vivifying Hash.
		def autovivify( hash, key )
			hash[ key ] = Hash.new( &Assemblage::DataUtilities.method(:autovivify) )
		end


		### Return a version of the given +hash+ with its keys transformed
		### into Strings from whatever they were before.
		def stringify_keys( hash )
			newhash = {}

			hash.each do |key,val|
				if val.is_a?( Hash )
					newhash[ key.to_s ] = stringify_keys( val )
				else
					newhash[ key.to_s ] = val
				end
			end

			return newhash
		end


		### Return a duplicate of the given +hash+ with its identifier-like keys
		### transformed into symbols from whatever they were before.
		def symbolify_keys( hash )
			newhash = {}

			hash.each do |key,val|
				keysym = key.to_s.dup.untaint.to_sym

				if val.is_a?( Hash )
					newhash[ keysym ] = symbolify_keys( val )
				else
					newhash[ keysym ] = val
				end
			end

			return newhash
		end
		alias_method :internify_keys, :symbolify_keys

	end # module DataUtilities


	# Methods for logging monitor events.
	module SocketMonitorLogging

		### Set up a monitor instance variable on object creation.
		def initialize( * ) # :notnew:
			@monitor = nil
		end

		##
		# The CZTop::Monitor for the server socket
		attr_reader :monitor


		### Handle monitor events.
		def on_monitor_event( monitor_event )
			self.log.debug "Got monitor event: %p" % [ monitor_event ]

			msg = monitor_event.socket.receive
			type, *payload = *msg
			callback_name = "on_#{type.downcase}"

			if self.respond_to?( callback_name, true )
				self.send( callback_name, *payload )
			else
				self.log.warn "No handler (#%s) for monitored %s event." % [ callback_name, type ]
			end
		end


		#########
		protected
		#########

		### Monitor event callback for socket connection events
		def on_connected( fd, endpoint )
			self.log.debug "Client socket on FD %d connected" % [ fd ]
		end


		### Monitor event callback for socket accepted events
		def on_accepted( fd, endpoint )
			self.log.debug "Client socket on FD %d accepted" % [ fd ]
		end


		### Monitor event callback for successful auth events.
		def on_handshake_succeeded( fd, endpoint )
			self.log.debug "Client socket on FD %d handshake succeeded" % [ fd ]
		end


		### Monitor event callback for failed auth events.
		def on_handshake_failed( fd, endpoint )
			self.log.debug "Client socket on FD %d handshake failed" % [ fd ]
		end


		### Monitor event callback for failed handshake events.
		def on_handshake_failed_no_detail( fd, endpoint )
			self.log.debug "Client socket on FD %d handshake failed; no further details are known" % [ fd ]
		end


		### Monitor event callback for failed handshake events.
		def on_handshake_failed_protocol( fd, endpoint )
			self.log.debug "Client socket on FD %d handshake failed: protocol error" % [ fd ]
		end


		### Monitor event callback for socket closed events
		def on_closed( fd, endpoint )
			self.log.debug "Client socket on FD %d closed" % [ fd ]
		end


		### Monitor event callback for socket disconnection events
		def on_disconnected( fd, endpoint )
			self.log.debug "Client socket on FD %d disconnected" % [ fd ]
		end

	end # module SocketMonitorLogging


end # module Assemblage
