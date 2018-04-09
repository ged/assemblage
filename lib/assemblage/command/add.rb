# -*- ruby -*-
# frozen_string_literal: true

require 'socket'
require 'assemblage/cli' unless defined?( Assemblage::CLI )
require 'assemblage/db_object'

# Command to add an Aeembly server to a worker's config
module Assemblage::CLI::AddServer
	extend Assemblage::CLI::Subcommand


	desc "Add connection information to a run directory."
	command :add do |add|

		add.desc "Add a new worker to a server"
		add.long_desc <<-END_DESC
		Add a cert and configuration for a new worker to a server run directory.
		END_DESC
		add.arg :NAME
		add.arg :PUBLIC_KEY
		add.command :worker do |worker|

			worker.action do |globals, options, args|
				name = args.shift or help_now!( "Missing the worker name." )
				public_key = args.shift or help_now!( "Missing the worker public key." )

				Assemblage.use_run_directory( args.shift )

				prompt.say "Approving connections from %s..." % [ name ]
				Assemblage::Server.add_worker( name, public_key )
				prompt.say "done."
			end

		end


		add.desc "Add a new server to a worker"
		add.long_desc <<-END_DESC
		Add a cert and configuration for a new server to a worker run directory.
		END_DESC
		add.arg :URL
		add.arg :PUBLIC_KEY
		add.command :server do |server|

			server.action do |globals, options, args|
				url = args.shift or help_now!( "Missing the server url." )
				public_key = args.shift or help_now!( "Missing the server public key." )

				Assemblage.use_run_directory( args.shift )
				Assemblage::Worker.add_server( url, public_key )

				prompt.say "Testing connection to %s..." % [ url ]
				Assemblage::Worker.test_connection( url, public_key )
				prompt.say "success."

				prompt.say "done."
			end
		end

	end

end # module Assemblage::CLI::AddServer

