# -*- ruby -*-
# frozen_string_literal: true

require 'socket'
require 'assemblage' unless defined?( Assemblage )


# A worker daemon that listens to the assembly server for assemblies to build
# and builds them.
class Assemblage::Worker
	extend Configurability,
	       Loggability

	# Regexp for testing worker names for validity
	WORKER_NAME_PATTERN = /\A[a-z][\w\-]+\z/i

	# The minimum number of characters for a worker name
	NAME_MIN_LENGTH = 3

	# The amximum number of characters for a worker name
	NAME_MAX_LENGTH = 35

	# The name given to workers by default
	DEFAULT_WORKER_NAME = "#{Socket.gethostname.gsub('.', '-').downcase}-worker1"


	# Loggability API -- log to the Assemblage logger.
	log_to :assemblage


	### Returns +true+ if the specified +name+ is valid for a worker's name.
	def self::valid_workername?( name )
		return WORKER_NAME_PATTERN.match?( name ) &&
			( NAME_MIN_LENGTH .. NAME_MAX_LENGTH ).cover?( name.length )
	end


	# Configurability API -- declare some settings for Workers.
	configurability( 'assemblage.worker' ) do

		setting :name, default: DEFAULT_WORKER_NAME do |name|
			raise ArgumentError, "invalid worker name %p" % [ name ] unless
				Assemblage::Worker.valid_workername?( name )
			name
		end


		setting :tags, default: [] do |tags|
			Array( tags )
		end

	end


	### Given a CZTop::Certificate, return the associated Player object.
	def self::from_cert( cert )
		name = Assemblage::Auth.workername_for_cert( cert )
		return self[ name: login ]
	end


	### Create a new worker that will run in the specified +directory+.
	def initialize( directory='.' )
		@directory = Pathname( directory || '.' ).expand_path
	end


	######
	public
	######

	##
	# The directory the worker will run in
	attr_reader :directory


	### Set up the Worker's directory as a worker run directory. Raises an
	### exception if the directory already exists and is not empty.
	def setup_run_directory( name, tags=[] )
		raise "Directory not empty" if self.directory.exist? && !self.directory.empty?

		self.log.debug "Attempting to set up %s as a run directory." % [ self.directory ]
		self.directory.mkpath
		self.directory.chmod( 0755 )

		config = Assemblage.config || Configurability.default_config
		config.assemblage.directory = self.directory.to_s
		config.assemblage.worker.name = name
		config.assemblage.worker.tags = tags

		config.write( self.directory + Assemblage::DEFAULT_CONFIG_FILE.basename )

		config.install
	end

end # class Assemblage::Worker

