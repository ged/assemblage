# -*- ruby -*-
#encoding: utf-8

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

end # module Assemblage

