#!/usr/bin/env rspec -cfd
#encoding: utf-8

require_relative 'spec_helper'

require 'rspec'
require 'assemblage'

describe Assemblage do

	it_should_behave_like "an object with Configurability"


	it "has a VERSION constant" do
		expect( described_class::VERSION ).to match( /\A\d+\.\d+\.\d+/ )
	end

end

