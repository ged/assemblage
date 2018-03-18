# -*- ruby -*-
# frozen_string_literal: true

require 'socket'
require 'assemblage/cli' unless defined?( Assemblage::CLI )
require 'assemblage/worker'


# Command to create a new Assembly worker
module Assemblage::CLI::CreateWorker
	extend Assemblage::CLI::Subcommand

	desc 'Set up a new assembly worker'
	long_desc <<-END_DESC
	Set up a new assembly worker in the given DIRECTORY. If the DIRECTORY is
	not specified, the current directory will be used. If the target directory
	is not empty, this command will abort.
	END_DESC
	arg :DIRECTORY
	command 'create-worker' do |cmd|

		cmd.desc "Specify a name that will identify the worker on any servers it registers with"
		cmd.flag [:n, :name], type: String,
			must_match: Assemblage::Worker::WORKER_NAME_PATTERN

		cmd.desc "Specify one or more tags that indicate what assemblies the worker should accept"
		cmd.flag [:t, :tags], type: Array

		cmd.action do |globals, options, args|
			directory = Pathname( args.shift || '.' ).expand_path

			name = options.name || "%s-%s" %
				[ Socket.gethostname.downcase.gsub('.', '-'), directory.basename ]
			tags = options.tags

			prompt.say "Creating a worker run directory in %s..." % [ directory ]
			worker = Assemblage::Worker.new( directory )
			worker.setup_run_directory( name, tags )
			Assemblage.load_config( directory + 'config.yml' )

			prompt.say "done."
		end
	end

end # module Assemblage::CLI::CreateWorker

