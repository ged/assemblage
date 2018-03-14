#!/usr/bin/env rspec -cfd

require 'tmpdir'
require_relative '../spec_helper'

require 'assemblage/server'


describe Assemblage::Server do

	before( :all ) do
		@original_store_dir = Assemblage::Auth.cert_store_dir
		Assemblage::Auth.reset
		@test_data_dir = Dir.mktmpdir( ['assemblage-rspec-', '-data'] )
	end

	after( :all ) do
		Assemblage::Auth.cert_store_dir = @original_store_dir
	end

	let( :assembly_dir ) { @test_data_dir }


	it "uses the current directory if none is specified"

end

