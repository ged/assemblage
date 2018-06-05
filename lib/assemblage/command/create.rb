# -*- ruby -*-
# frozen_string_literal: true

require 'assemblage/cli' unless defined?( Assemblage::CLI )


# Command to create a new Assembly server
module Assemblage::CLI::CreateServer
	extend Assemblage::CLI::Subcommand

	SERVER_ADVICE = %{
		You can start the assembly server like so:
		  assemblage start server %{directory}

		Server public key is:
		  %{public_key}

	}.gsub( /^\t+/, '' )


	WORKER_ADVICE = %{
		Now you can register this worker with a server like so:
		  assemblage add worker %{name} "%{public_key}" <server directory>

		Once it is registered, you can start the assembly worker like so:
		  assemblage start worker %{directory}

	}.gsub( /^\t+/, '' )


	desc "Create a run directory for an Assemblage server or worker"
	command :create do |create|

		create.desc 'Set up a new assembly server'
		create.long_desc <<-END_DESC
		Set up a new assembly server in the given DIRECTORY. If the DIRECTORY is
		not specified, the current directory will be used. If the target directory
		is not empty, this command will abort.
		END_DESC
		create.arg :DIRECTORY
		create.command :server do |server|
			server.action do |globals, options, args|
				directory = Pathname( args.shift || '.' ).expand_path

				prompt.say "Creating a server run directory in %s..." % [ directory ]
				Assemblage::Server.setup_run_directory( directory )

				prompt.say "Generating a server key..."
				Assemblage::Server.generate_cert

				prompt.say "Creating the assemblies database..."
				Assemblage::Server.create_database

				msg = SERVER_ADVICE % {
					public_key: Assemblage::Server.public_key,
					directory: directory
				}
				prompt.say( msg )
			end
		end


		create.desc 'Set up a new assembly worker'
		create.long_desc <<-END_DESC
		Set up a new assembly worker in the given DIRECTORY. If the DIRECTORY is
		not specified, the current directory will be used. If the target directory
		is not empty, this command will abort.
		END_DESC
		create.arg :DIRECTORY
		create.command :worker do |worker|

			worker.desc "Specify a name that will identify the worker on any servers it registers with"
			worker.flag [:N, :name], type: String,
				must_match: Assemblage::Auth::CLIENT_NAME_PATTERN

			worker.desc "Specify one or more tags that indicate what assemblies the worker should accept"
			worker.flag [:t, :tags], type: Array

			worker.action do |globals, options, args|
				directory = Pathname( args.shift || '.' ).expand_path

				name = options.name || "%s-%s" %
					[ Socket.gethostname.downcase.gsub('.', '-'), directory.basename ]
				tags = options.tags

				prompt.say "Creating a worker run directory in %s..." % [ directory ]
				Assemblage::Worker.setup_run_directory( directory, name, tags )

				prompt.say "Generating a worker key..."
				Assemblage::Worker.generate_cert

				msg = WORKER_ADVICE % {
					name: name,
					public_key: Assemblage::Worker.public_key,
					directory: directory
				}
				prompt.say( msg )
			end
		end

	end

end # module Assemblage::CLI::CreateServer

