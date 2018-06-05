# -*- ruby -*-
# frozen_string_literal: true

require 'hglib'

require 'assemblage/vcs_strategy' unless defined?( Assemblage::VCSStrategy )


# A version control strategy for operations on a Mercurial repo.
class Assemblage::VCSStrategy::Mercurial < Assemblage::VCSStrategy

	### Clone the repository at the given +url+ into the specified +directory+ at
	### the specified +revision+.
	def clone( url, directory, revision )
		Hglib.clone( url, directory, updaterev: revision )
	end

end # class Assemblage::VCSStrategy::Mercurial
