# -*- ruby -*-
# frozen_string_literal: true

require 'pathname'

require 'assemblage' unless defined?( Assemblage )


# The Assembly server.
#
# This gathers events from repositories and dispatches them to workers via one
# or more "assemblies". An assembly is the combination of a repository and one
# or more tags that describe pre-requisites for building a particular product.
class Assemblage::Server

	### Create a new Assemblage::Server that will run in the specified +directory+.
	def initialize( directory=Pathname('.') )
		@directory = directory
	end


	######
	public
	######

	##
	# The Pathname of the Server's run directory.
	attr_reader :directory




end # class Assemblage::Server

