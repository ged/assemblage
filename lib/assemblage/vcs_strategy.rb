# -*- ruby -*-
# frozen_string_literal: true

require 'pathname'
require 'pluggability'

require 'assemblage' unless defined?( Assemblage )


# Version control strategy -- used to provide a common interface to repository
# operations for various version control systems.
class Assemblage::VCSStrategy
	extend Pluggability

	plugin_paths 'assemblage/vcs_strategy'


	### Clone the repository at the given +url+ into the specified +directory+ at
	### the specified +revision+.
	def self::clone( url, directory, revision )
		raise NotImplementedError, "%p doesn't implement %s" % [ self.class, __method__ ]
	end

end # class Assemblage::VCSStrategy

