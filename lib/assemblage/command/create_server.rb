# -*- ruby -*-
# frozen_string_literal: true

require 'assemblage/cli' unless defined?( Assemblage::CLI )


# Command to create a new Assembly server
module Assemblage::CLI::CreateServer
	extend Assemblage::CLI::Subcommand

	desc 'Set up a new assembly server'
	log_desc <<-END_DESC
	Set up a new assembly server in the given DIRECTORY. If the DIRECTORY is
	not specified, the current directory will be used. If the target directory
	is not empty, this command will abort.
	END_DESC
	arg :DIRECTORY
	command :create_server do |cmd|
		cmd.action do |globals, options, args|
			directory = Pathname( args.shift || '.' ).expand_path

			abort_now!( "Target directory is not empty." ) unless directory.empty?

			prompt.say "Creating a server run directory in %s..." % [ directory ]
			s = Assemblage::Server.new( directory )
			s.setup_run_directory

			prompt.say "Generating a server key..."
			s.generate_key

			prompt.say "Creating the assemblies database..."
			s.create_database

			config_path = directory + 'config.yml'
			Configurability.default_config.write( config_path )
			prompt.say "done."

			prompt.say <<-"END_OF_ADVICE"
		    You can start the assembly server like so:
		      assemblage start-server #{directory}

		    Server public key is:
		      #{s.public_key}

			END_OF_ADVICE
		end
	end

end # module Assemblage::CLI::New

