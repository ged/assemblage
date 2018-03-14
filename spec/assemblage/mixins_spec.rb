#!/usr/bin/env rspec -cfd

require_relative '../spec_helper'

require 'assemblage/mixins'


describe Assemblage, "mixins" do

	describe Assemblage::MethodUtilities, 'used to extend a class' do

		let!( :extended_class ) do
			klass = Class.new
			klass.extend( Assemblage::MethodUtilities )
			klass
		end

		it "can declare a class-level attribute reader" do
			extended_class.singleton_attr_reader :foo
			expect( extended_class ).to respond_to( :foo )
			expect( extended_class ).to_not respond_to( :foo= )
			expect( extended_class ).to_not respond_to( :foo? )
		end

		it "can declare a class-level attribute writer" do
			extended_class.singleton_attr_writer :foo
			expect( extended_class ).to_not respond_to( :foo )
			expect( extended_class ).to respond_to( :foo= )
			expect( extended_class ).to_not respond_to( :foo? )
		end

		it "can declare a class-level attribute reader and writer" do
			extended_class.singleton_attr_accessor :foo
			expect( extended_class ).to respond_to( :foo )
			expect( extended_class ).to respond_to( :foo= )
			expect( extended_class ).to_not respond_to( :foo? )
		end

		it "can declare a class-level alias" do
			def extended_class.foo
				return "foo"
			end
			extended_class.singleton_method_alias( :bar, :foo )

			expect( extended_class.bar ).to eq( 'foo' )
		end

		it "can declare an instance attribute predicate method" do
			extended_class.attr_predicate :foo
			instance = extended_class.new

			expect( instance ).to_not respond_to( :foo )
			expect( instance ).to_not respond_to( :foo= )
			expect( instance ).to respond_to( :foo? )

			expect( instance.foo? ).to be_falsey

			instance.instance_variable_set( :@foo, 1 )
			expect( instance.foo? ).to be_truthy
		end

		it "can declare an instance attribute predicate and writer" do
			extended_class.attr_predicate_accessor :foo
			instance = extended_class.new

			expect( instance ).to_not respond_to( :foo )
			expect( instance ).to respond_to( :foo= )
			expect( instance ).to respond_to( :foo? )

			expect( instance.foo? ).to be_falsey

			instance.foo = 1
			expect( instance.foo? ).to be_truthy
		end

		it "can declare a class-level attribute predicate and writer" do
			extended_class.singleton_predicate_accessor :foo
			expect( extended_class ).to_not respond_to( :foo )
			expect( extended_class ).to respond_to( :foo= )
			expect( extended_class ).to respond_to( :foo? )
		end


		it "can declare a class-level predicate method" do
			extended_class.singleton_predicate_reader :foo
			expect( extended_class ).to_not respond_to( :foo )
			expect( extended_class ).to_not respond_to( :foo= )
			expect( extended_class ).to respond_to( :foo? )
		end


		it "can declare an instance DSLish accessor" do
			extended_class.dsl_accessor( :foo )
			instance = extended_class.new

			instance.foo( 13 )
			expect( instance.foo ).to eq( 13 )
		end


		it "the instance DSLish accessor works with a `false` argument" do
			extended_class.dsl_accessor( :foo )
			instance = extended_class.new

			instance.foo( false )
			expect( instance.foo ).to equal( false )
		end

	end

end

