# -*- ruby -*-
# frozen_string_literal: true

require 'assemblage/cli' unless defined?( Assemblage::CLI )
require 'assemblage/client'

# Command to ack a node
module Assemblage::CLI::New
	extend Assemblage::CLI::Subcommand

	desc 'Set up a new assemblage with the specified NAME'
	log_desc <<-END_DESC
	Set up a new assemblage with the specified NAME that will clone from 
	the given URL.
	END_DESC
	arg :NAME
	arg :URL
	command :new do |cmd|

		cmd.flag [ :r, :repo_type ],
			desc: "The type of repository.",
			default_value: 'hg'

		cmd.action do |globals, options, args|
			name = args.shift or help_now!( "No name specified." )
			url = args.shift or help_now!( "No URL specified." )

			assemblage = Assemblage.new( name, url )

			assemblage.
		end
	end

end # module Assemblage::CLI::New

