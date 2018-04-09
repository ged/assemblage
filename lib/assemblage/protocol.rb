# -*- ruby -*-
#encoding: utf-8

require 'e2mmap'
require 'msgpack'
require 'assemblage' unless defined?( Assemblage )


# A container for functions that manipulate events in the Assemblage hub protocol
module Assemblage::Protocol
	extend Exception2MessageMapper,
	       Assemblage::DataUtilities


	# The version of the protocol
	VERSION = 1

	# A Regexp describing valid `type` header values
	VALID_TYPE_PATTERN = /\A[a-z]\w+\z/

	# The default headers included in every message
	DEFAULT_HEADER = {
		version: VERSION,
	}


	# Exceptions raised while decoding
	def_exception :Error, "protocol error", ArgumentError


	### Check the specified message +header+ for sanity, and raise an
	### Assemblage::Protocol::Error if there is a problem with it.
	def self::check_message_header( header )
		self.check_message_version( header )
		self.check_message_type( header )
	end


	### Check the `version` specified in the given message +header+, raising an
	### Assemblage::Protocol::Error if it isn't present or isn't the same as VERSION.
	def self::check_message_version( header )
		version = header[:version] or
			raise Assemblage::Protocol::Error, "malformed message header: no version"
		if version != VERSION
			raise Assemblage::Protocol::Error,
				"version mismatch: expected %p, got %p" %
				[ VERSION, version ]
		end
	end


	### Check the `type` specified in the given message +header+, raising an
	### Assemblage::Protocol::Error if there is a problem with it.
	def self::check_message_type( header )
		type = header[:type] or
			raise Assemblage::Protocol::Error, "malformed message header: no type"
		unless VALID_TYPE_PATTERN.match?( type )
			raise Assemblage::Protocol::Error, "malformed message type: %p" % [ type ]
		end
	end


	###############
	module_function
	###############

	### Encode a message of the specified +type+ and return it as a CZTop::Message.
	def encode( type, data, header={} )
		header = DEFAULT_HEADER.merge( symbolify_keys(header) ).merge( type: type )
		Assemblage::Protocol.check_message_header( header )

		raw_message = [ header, data ]
		encoded = MessagePack.pack( raw_message )

		return CZTop::Message.new( encoded )
	end


	### Decode the given +message+ (a CZTop::Message) and return the type of
	### message, the data of the payload, and the header as a Hash with Symbol keys.
	def decode( message )
		encoded = message[ 0 ]

		raw_message = MessagePack.unpack( encoded )
		header, data = *raw_message
		header = symbolify_keys( header )

		Assemblage::Protocol.check_message_header( header )

		type = header.delete( :type )
		return type.to_sym, data, header
	end


	### Construct a HELLO message from the specified +sender+.
	def hello_from( sender )
		type = sender.class.name.sub( /.*::/, '' ).downcase
		version = Assemblage::VERSION
		now = Time.now.to_f

		return Assemblage::Protocol.encode( :hello, [type, version, now] )
	end


	### Construct a GOODBYE message from the specified +sender+.
	def goodbye_from( sender )
		return Assemblage::Protocol.encode( :goodbye, [] )
	end


	### Construct a message for an observer event of the given +type+ and +data+.
	def observer_event( type, *data )
		return Assemblage::Protocol.encode( :observer_event, [type, *data] )
	end

end # module Assemblage::Protocol
