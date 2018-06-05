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
				Assemblage::Server.run( args.shift )
			end
		end


		start.desc 'Start an assembly worker'
		start.long_desc <<-END_DESC
		Start an Assemblage worker in the specified DIRECTORY. If not specified, the
		DIRECTORY will default to the current working directory.
		END_DESC
		start.arg :DIRECTORY, :optional
		start.command :worker do |server|
			server.action do |globals, options, args|
				Assemblage::Worker.run( args.shift )
			end
		end

	end

end # module Assemblage::CLI::StartServer

