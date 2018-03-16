# -*- ruby -*-
#encoding: utf-8

require 'tsort'
require 'sequel'

require 'assemblage' unless defined?( Assemblage )
require 'assemblage/mixins'


# Set up an abstract base model class and a factory method for creating
# subclasses.
Assemblage::DbObject = Class.new( Sequel::Model )
module Assemblage
	def self::DbObject( source )
		Assemblage::DbObject.Model( source )
	end
end


class Assemblage::DbObject
	extend TSort,
	       Loggability,
	       Assemblage::MethodUtilities,
	       Configurability


	# Loggability API -- log to Assemblage's logger
	log_to :assemblage

	#
	# Sequel extensions and plugins
	#
	Sequel.extension( :migration )
	Sequel.extension( :core_refinements )

	plugin :dirty
	plugin :subclasses
	plugin :force_encoding, 'UTF-8'
	plugin :validation_helpers


	##
	# :singleton-method:
	# The Set of model class files to load after the connection is established
	singleton_attr_reader :registered_models
	@registered_models = Set.new


	# Configurability API
	configurability( 'assemblage.db' ) do

		##
		# :singleton-method:
		# The URI of the database to connect to
		setting :uri, default: 'sqlite:/'

		##
		# :singleton-method:
		# A Hash of options to use when creating the database connections
		setting :options, default: { log_warn_duration: 0.02 }

	end


	### Reset the database connection that all model objects will use to +newdb+ (a
	### Sequel::Database object).
	def self::db=( newdb )
		newdb.sql_log_level = :debug
		newdb.logger = Loggability[ Assemblage::DbObject ]

		super

		self.descendents.each do |subclass|
			subclass.dataset = newdb[ subclass.table_name ]
		end
	end


	### Add a +path+ to require once the database connection is set.
	def self::register_model( path )
		self.log.debug "Registered model for requiring: %s" % [ path ]

		# If the connection's set, require the path immediately.
		Loggability.for_logger( self ).with_level( :fatal ) do
			require( path )
		end if @db

		self.registered_models.add( path )
	end


	### Require the model classes once the database connection has been established
	def self::require_models
		self.log.debug "Loading registered model classes."
		logging_override = Loggability.for_logger( self ).with_level( :fatal )
		self.registered_models.each do |path|
			logging_override.call { require path }
		end
	end


	### Configurability interface -- Configure the Sequel connection
	def self::configure( config=nil )
		super

		if self.uri
			Loggability[ Assemblage::DbObject ].debug "Connecting to %s" % [ self.uri ]
			self.db = Sequel.connect( self.uri, self.options )
		end

	end


	### Set up the metastore database and migrate to the latest version.
	def self::setup_database
		unless self.database_is_current?
			self.log.info "Installing database schema in %s..." % [ self.db ]
			Sequel::Migrator.apply( self.db, self.migrations_dir.to_s )
		end
	end


	### Returns +true+ if the database for the model classes exist.
	def self::database_is_current?
		return Loggability.with_level( :fatal ) do
			Sequel::Migrator.is_current?( self.db, self.migrations_dir.to_s )
		end
	end


	### Tear down the configured metastore database.
	def self::teardown_database
		self.log.info "Tearing down database schema..."
		Sequel::Migrator.apply( self.db, self.migrations_dir.to_s, 0 )
	end


	### Return the current database migrations directory as a Pathname
	def self::migrations_dir
		return Assemblage::DATADIR + 'migrations'
	end


	# Load models after the system is configured
	Assemblage.after_configure do
		Assemblage::DbObject.require_models
	end

end # class Assemblage::DbObject

