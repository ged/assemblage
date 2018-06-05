# -*- ruby -*-
# frozen_string_literal: true

require 'cztop'

require 'assemblage' unless defined?( Assemblage )
require 'assemblage/db_object'
require 'assemblage/protocol'


class Assemblage::Client < Assemblage::DbObject( :clients )


	### Overridden to add a few non-column instance variables.
	def initialize( * )
		super

		@routing_id = nil
		@server = nil
	end


	######
	public
	######

	##
	# The routing ID associated with the client's socket.
	attr_reader :routing_id

	##
	# The server the client is connected to.
	attr_reader :server


	### Connection callback -- called when the +server+ handles the first message.
	def on_connected( server, routing_id )
		self.log.info "%s [%s]: Connected with routing ID %p" %
			[ self.type, self.name, routing_id ]

		@server = server
		@routing_id = routing_id
	end


	### Connection callback -- called just before the server instructs the client to
	### disconnect.
	def on_disconnected
		self.log.info "%s [%s]: Disconnecting."
		@routing_id = nil
		@server = nil
	end


	### Return a CZTop::Message to send to the client with the specified +type+ and
	### +data+.
	def make_response( type, data, **headers )
		return unless self.routing_id
		msg = Assemblage::Protocol.encode( type, data, headers )
		msg.routing_id = self.routing_id
		return msg
	end


	### Return a CZTop::Message to send to the client that indicates an +error+ occurred.
	def make_error_response( error )
		return self.make_response( :error, error.message, success: false )
	end

end # class Assemblage::Client

