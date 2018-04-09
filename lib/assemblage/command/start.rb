# -*- ruby -*-
# frozen_string_literal: true

require 'pathname'
require 'assemblage/cli' unless defined?( Assemblage::CLI )


# Command to start a Assemblage server
module Assemblage::CLI::StartServer
	extend Assemblage::CLI::Subcommand


	desc "Start an Assemblage daemon"
	command :start do |start|

		start.desc 'Start an assembly server'
		start.long_desc <<-END_DESC
		Start the Assemblage server in the specified DIRECTORY. If not specified, the
		DIRECTORY will default to the current working directory.
		END_DESC
		start.arg :DIRECTORY, :optional
		start.command :server do |server|
			server.action do |globals, options, args|
				directory = Pathname( args.shift || '.' )

				Dir.chdir( directory )
				Assemblage.load_config( directory + 'config.yml' )

				server = Assemblage::Server.new

				prompt.say( headline_string "Starting assembly server..." )
				thr = Thread.new { server.run }
				sleep 0.2 until server.running?
				prompt.say( "  listening at: %s" % [server.last_endpoint] )
				thr.join
			end
		end

	end

end # module Assemblage::CLI::StartServer

