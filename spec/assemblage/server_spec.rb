#!/usr/bin/env rspec -cfd

require 'tmpdir'
require 'fileutils'

require_relative '../spec_helper'

require 'assemblage/server'


describe Assemblage::Server do

	before( :all ) do
		@original_store_dir = Assemblage::Auth.cert_store_dir
		Assemblage::Auth.reset
		@test_data_dir = Pathname( Dir.mktmpdir('assemblage-rspec-') )
	end

	after( :all ) do
		Assemblage::Auth.cert_store_dir = @original_store_dir
		FileUtils.rm_rf( @test_data_dir )
	end


	let( :assemblage_dir ) do
		a_dir = Dir::Tmpname.create( 'assemblage-', @test_data_dir ) {}
		Pathname( a_dir )
	end


	it_should_behave_like "an object with Configurability"


	describe "new directory setup" do

		it "can set up a new run directory" do
			described_class.setup_run_directory( assemblage_dir )

			expect( assemblage_dir ).to exist
			expect( assemblage_dir.stat.mode & 0777 ).to eq( 0755 )
			expect( assemblage_dir ).to_not be_world_writable

			config_file = assemblage_dir + 'config.yml'
			expect( config_file ).to exist
			expect( config_file.read ).to start_with( '--' )

			database = assemblage_dir + 'assemblage.db'
			expect( database ).to exist
			expect( database ).to be_empty
		end


		it "raises an exception if the directory isn't empty" do
			assemblage_dir.mkpath
			existing_file = assemblage_dir + 'some-file.txt'
			existing_file.write( "Hi!" )

			expect {
				described_class.setup_run_directory( assemblage_dir )
			}.to raise_error( /directory not empty/i )
		end

	end


	describe "signal-handling" do

		before( :each ) do
			@old_pwd = Pathname.pwd

			described_class.setup_run_directory( assemblage_dir )
			described_class.generate_cert
			described_class.create_database

			Assemblage.use_run_directory( assemblage_dir )
			@server = described_class.new

			@server_thread = Thread.new do
				Thread.current.abort_on_exception = true
				@server.run
			end
		end

		after( :each ) do
			@server.stop if @server
			@server_thread.kill unless !@server_thread || @server_thread.join( 2 )
			Dir.chdir( @old_pwd )
		end


		it "stops when sent a TERM signal" do
			wait( 1 ).for { @server.running? }.to be_truthy
			@server.simulate_signal( :TERM )
			wait( 1 ).for { @server.stopped? }.to be_truthy
		end


		it "stops when sent an INT signal" do
			wait( 1 ).for { @server.running? }.to be_truthy
			@server.simulate_signal( :INT )
			wait( 1 ).for { @server.stopped? }.to be_truthy
		end


		it "stops when sent a HUP signal" do
			wait( 1 ).for { @server.running? }.to be_truthy
			@server.simulate_signal( :HUP )
			wait( 1 ).for { @server.stopped? }.to be_truthy
		end

	end

end

