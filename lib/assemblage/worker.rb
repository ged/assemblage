# -*- ruby -*-
# frozen_string_literal: true

require 'assemblage' unless defined?( Assemblage )


# A worker daemon that listens to the assembly server for assemblies to build
# and builds them.
class Assemblage::Worker

	# Regexp for testing worker names for validity
	WORKER_NAME_PATTERN = /\A[a-z][\w\-]+\z/i

	# The minimum number of characters for a worker name
	NAME_MIN_LENGTH = 3

	# The amximum number of characters for a worker name
	NAME_MAX_LENGTH = 16


	### Returns +true+ if the specified +name+ is valid for a worker's name.
	def self::valid_workername?( name )
		return WORKER_NAME_PATTERN.match( name ) &&
			( NAME_MIN_LENGTH .. NAME_MAX_LENGTH ).cover?( name.length )
	end


	### Given a CZTop::Certificate, return the associated Player object.
	def self::from_cert( cert )
		name = Assemblage::Auth.workername_for_cert( cert )
		return self[ name: login ]
	end

end # class Assemblage::Worker

