# -*- ruby -*-
# frozen_string_literal: true

require 'configurability'
require 'loggability'
require 'pathname'

require 'assemblage' unless defined?( Assemblage )
require 'assemblage/auth'
require 'assemblage/db_object'


# The Assembly server.
#
# This gathers events from repositories and dispatches them to workers via one
# or more "assemblies". An assembly is the combination of a repository and one
# or more tags that describe pre-requisites for building a particular product.
class Assemblage::Server
	extend Loggability


	# Log to the Assemblage logger
	log_to :assemblage


	### Create a new Assemblage::Server that will run in the specified +directory+.
	def initialize( directory='.' )
		@directory = Pathname( directory || '.' ).expand_path
	end


	######
	public
	######

	##
	# The Pathname of the Server's run directory.
	attr_reader :directory


	### Set up the Server's directory as an Assemblage run directory. Raises an
	### exception if the directory already exists and is not empty.
	def setup_run_directory
		raise "Directory not empty" if self.directory.exist? && !self.directory.empty?

		self.log.debug "Attempting to set up %s as a run directory." % [ self.directory ]
		self.directory.mkpath
		self.directory.chmod( 0755 )

		config = Assemblage.config || Configurability.default_config
		config.assemblage.directory = self.directory.to_s
		config.assemblage.auth.cert_store_dir ||= (self.directory + 'certs').to_s
		config.assemblage.db.uri = "sqlite:%s" % [ self.directory + 'assemblage.db' ]

		config.write( self.directory + Assemblage::DEFAULT_CONFIG_FILE.basename )

		config.install
	end


	### Generate a new server cert/keypair for authentication.
	def generate_cert
		Assemblage::Auth.generate_server_cert
	end


	### Return the server's public key as a Z85-encoded ASCII string.
	def public_key
		return Assemblage::Auth.server_cert.public_key
	end


	### Create the database the assembly information is tracked in.
	def create_database
		Assemblage::DbObject.setup_database
	end

end # class Assemblage::Server

