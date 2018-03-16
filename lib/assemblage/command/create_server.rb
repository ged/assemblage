# -*- ruby -*-
# frozen_string_literal: true

require 'assemblage/cli' unless defined?( Assemblage::CLI )


# Command to create a new Assembly server
module Assemblage::CLI::CreateServer
	extend Assemblage::CLI::Subcommand

	ADVICE = %{
		You can start the assembly server like so:
		  assemblage start-server %{directory}

		Server public key is:
		  %{public_key}

	}.gsub( /^\t+/, '' )

	desc 'Set up a new assembly server'
	long_desc <<-END_DESC
	Set up a new assembly server in the given DIRECTORY. If the DIRECTORY is
	not specified, the current directory will be used. If the target directory
	is not empty, this command will abort.
	END_DESC
	arg :DIRECTORY
	command 'create-server' do |cmd|
		cmd.action do |globals, options, args|
			directory = Pathname( args.shift || '.' ).expand_path

			prompt.say "Creating a server run directory in %s..." % [ directory ]
			s = Assemblage::Server.new( directory )
			s.setup_run_directory
			Assemblage.load_config( directory + 'config.yml' )

			prompt.say "Generating a server key..."
			s.generate_cert

			prompt.say "Creating the assemblies database..."
			s.create_database

			prompt.say( ADVICE % {public_key: s.public_key, directory: directory} )
		end
	end

end # module Assemblage::CLI::CreateServer

