# -*- ruby -*-
#encoding: utf-8

require 'simplecov' if ENV['COVERAGE']

require 'rspec'
require 'rspec/wait'
require 'loggability/spechelpers'
require 'configurability/behavior'

require 'assemblage'


### Mock with RSpec
RSpec.configure do |config|
	config.run_all_when_everything_filtered = true
	config.filter_run :focus
	config.order = 'random'
	config.mock_with( :rspec ) do |mock|
		mock.syntax = :expect
	end

	# rspec-wait
	config.wait_timeout = 3

	config.include( Loggability::SpecHelpers )
end


