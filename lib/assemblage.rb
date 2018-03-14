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


end # module Assemblage

