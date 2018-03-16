# -*- ruby -*-
# frozen_string_literal: true

require 'assemblage/cli' unless defined?( Assemblage::CLI )


# Command to start a Assemblage server
module Assemblage::CLI::StartServer
	extend Assemblage::CLI::Subcommand

	desc 'Start an assembly server'
	long_desc <<-END_DESC
	Start the Assemblage server in the specified DIRECTORY. If not specified, the
	DIRECTORY will default to the current working directory.
	END_DESC
	arg :DIRECTORY
	command 'start-server' do |cmd|
		cmd.action do |globals, options, args|
			directory = Pathname( args.shift || '.' ).expand_path
			server = Assemblage::Server.new( directory )

			prompt.say( headline_string "Starting assembly server..." )
			thr = server.start
			prompt.say( "  listening at: %s" % [server.socket.last_endpoint] )
			thr.join
		end
	end

end # module Assemblage::CLI::StartServer

