# -*- ruby -*-
#encoding: utf-8

require 'set'
require 'loggability'
require 'configurability'


# Toplevel namespace
module Assemblage
	extend Loggability,
	       Configurability

	# Package version
	VERSION = '0.0.1'

	# Version control revision
	REVISION = %q$Revision$

	# The name of the environment variable which can be used to set the config path
	CONFIG_ENV = 'ASSEMBLAGE_CONFIG'

	# The name of the config file for local overrides.
	LOCAL_CONFIG_FILE = Pathname( '~/.assemblage.yml' ).expand_path

	# The name of the config file that's loaded if none is specified.
	DEFAULT_CONFIG_FILE = Pathname( 'config.yml' ).expand_path

	# The data directory for the gem
	DATADIR = if ENV['ASSEMBLAGE_DATADIR']
			Pathname( ENV['ASSEMBLAGE_DATADIR'] )
		elsif Gem.loaded_specs[ 'assemblage' ] &&
			File.exist?( Gem.loaded_specs['assemblage'].datadir )
			Pathname( Gem.loaded_specs['assemblage'].datadir )
		else
			Pathname( __FILE__ ).dirname.parent + 'data/assemblage'
		end


	# Loggability API
	log_as :assemblage


	# Configurability API
	configurability( :assemblage ) do

		setting :directory

	end

	# Autoload subordinate modules
	autoload :Auth, 'assemblage/auth'
	autoload :CLI, 'assemblage/cli'
	autoload :Server, 'assemblage/server'
	autoload :Worker, 'assemblage/worker'


	require 'assemblage/mixins'
	extend Assemblage::MethodUtilities

	##
	# An Array of callbacks to be run after the config is loaded
	singleton_attr_reader :after_configure_hooks
	@after_configure_hooks = Set.new

	##
	# True if the after_configure hooks have already (started to) run.
	singleton_predicate_reader :after_configure_hooks_run
	@after_configure_hooks_run = false


	#
	# :section: Configuration API
	#

	### Get the loaded config (a Configurability::Config object)
	def self::config
		Configurability.loaded_config
	end


	### Returns +true+ if the configuration has been loaded at least once.
	def self::config_loaded?
		return self.config ? true : false
	end


	### Load the specified +config_file+, install the config in all objects with
	### Configurability, and call any callbacks registered via #after_configure.
	def self::load_config( config_file=nil, defaults=nil )
		config_file ||= ENV[ CONFIG_ENV ]
		config_file ||= LOCAL_CONFIG_FILE if LOCAL_CONFIG_FILE.exist?
		config_file ||= DEFAULT_CONFIG_FILE

		defaults    ||= Configurability.gather_defaults

		self.log.info "Loading config from %p with defaults for sections: %p." %
			[ config_file, defaults.keys ]
		config = Configurability::Config.load( config_file, defaults )

		config.install
	end


	### Register a callback to be run after the config is loaded.
	def self::after_configure( &block )
		raise LocalJumpError, "no block given" unless block
		self.after_configure_hooks << block

		# Call the block immediately if the hooks have already been called or are in
		# the process of being called.
		block.call if self.after_configure_hooks_run?
	end
	singleton_method_alias :after_configuration, :after_configure


	### Call the post-configuration callbacks.
	def self::call_after_configure_hooks
		self.log.debug "  calling %d post-config hooks" % [ self.after_configure_hooks.length ]
		self.after_configure_hooks_run = true

		self.after_configure_hooks.to_a.each do |hook|
			self.log.debug "    %s line %s..." % hook.source_location
			hook.call
		end
	end

end # module Assemblage

