# -*- ruby -*-
# frozen_string_literal: true

# A collection of generically-useful mixins
module Assemblage

	# A collection of methods for declaring other methods.
	#
	#   class MyClass
	#       extend Assemblage::MethodUtilities
	#
	#       singleton_attr_accessor :types
	#       singleton_method_alias :kinds, :types
	#   end
	#
	#   MyClass.types = [ :pheno, :proto, :stereo ]
	#   MyClass.kinds # => [:pheno, :proto, :stereo]
	#
	module MethodUtilities

		### Creates instance variables and corresponding methods that return their
		### values for each of the specified +symbols+ in the singleton of the
		### declaring object (e.g., class instance variables and methods if declared
		### in a Class).
		def singleton_attr_reader( *symbols )
			singleton_class.instance_exec( symbols ) do |attrs|
				attr_reader( *attrs )
			end
		end

		### Create instance variables and corresponding methods that return
		### true or false values for each of the specified +symbols+ in the singleton
		### of the declaring object.
		def singleton_predicate_reader( *symbols )
			singleton_class.extend( Assemblage::MethodUtilities )
			singleton_class.attr_predicate( *symbols )
		end

		### Creates methods that allow assignment to the attributes of the singleton
		### of the declaring object that correspond to the specified +symbols+.
		def singleton_attr_writer( *symbols )
			singleton_class.instance_exec( symbols ) do |attrs|
				attr_writer( *attrs )
			end
		end

		### Creates readers and writers that allow assignment to the attributes of
		### the singleton of the declaring object that correspond to the specified
		### +symbols+.
		def singleton_attr_accessor( *symbols )
			symbols.each do |sym|
				singleton_class.__send__( :attr_accessor, sym )
			end
		end

		### Create predicate methods and writers that allow assignment to the attributes
		### of the singleton of the declaring object that correspond to the specified
		### +symbols+.
		def singleton_predicate_accessor( *symbols )
			singleton_class.extend( Assemblage::MethodUtilities )
			singleton_class.attr_predicate_accessor( *symbols )
		end

		### Creates an alias for the +original+ method named +newname+.
		def singleton_method_alias( newname, original )
			singleton_class.__send__( :alias_method, newname, original )
		end


		### Create a reader in the form of a predicate for the given +attrname+.
		def attr_predicate( attrname )
			attrname = attrname.to_s.chomp( '?' )
			define_method( "#{attrname}?" ) do
				instance_variable_get( "@#{attrname}" ) ? true : false
			end
		end


		### Create a reader in the form of a predicate for the given +attrname+
		### as well as a regular writer method.
		def attr_predicate_accessor( attrname )
			attrname = attrname.to_s.chomp( '?' )
			attr_writer( attrname )
			attr_predicate( attrname )
		end


		### Create an method that is both a reader and a writer for an instance
		### variable. If called with a (non-nil) argument, it will set the variable to
		### the new value. It returns whatever the instance variable is set to.
		def dsl_accessor( attrname )
			define_method( attrname ) do |arg=nil|
				instance_variable_set( "@#{attrname}", arg ) unless arg.nil?
				return instance_variable_get( "@#{attrname}" )
			end
		end

	end # module MethodUtilities

end # module Assemblage
