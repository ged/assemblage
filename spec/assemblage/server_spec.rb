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

	let( :assembly_dir ) do
		a_dir = Dir::Tmpname.create( 'assembly-', @test_data_dir ) {}
		Pathname( a_dir )
	end


	it "uses the current directory for the run directory if none is specified" do
		server = described_class.new

		expect( server ).to be_a( described_class )
		expect( server.directory ).to eq( Pathname.pwd )
	end


	it "can be created with a non-existant run directory" do
		server = described_class.new( assembly_dir )

		expect( server ).to be_a( described_class )
		expect( server.directory ).to eq( assembly_dir )
	end


	describe "new directory setup" do

		it "can set up a new run directory" do
			server = described_class.new( assembly_dir )

			server.setup_run_directory

			expect( assembly_dir ).to exist
			expect( assembly_dir.stat.mode & 0777 ).to eq( 0755 )
			expect( assembly_dir ).to_not be_world_writable

			config_file = assembly_dir + 'config.yml'
			expect( config_file ).to exist
			expect( config_file.read ).to start_with( '--' )

			database = assembly_dir + 'assemblage.db'
			expect( database ).to exist
			expect( database ).to be_empty
		end


		it "raises an exception if the directory isn't empty" do
			assembly_dir.mkpath
			existing_file = assembly_dir + 'some-file.txt'
			existing_file.write( "Hi!" )

			server = described_class.new( assembly_dir )

			expect {
				server.setup_run_directory
			}.to raise_error( /directory not empty/i )
		end

	end


	describe "auth certificate generation" do

		before( :all ) do
			@cert_store_dir = @test_data_dir + 'certs'
			Assemblage::Auth.cert_store_dir = @cert_store_dir
		end

		before( :each ) do
			FileUtils.rm_rf( @cert_store_dir )
		end


		it "can generate a new zauth keypair" do
			server = described_class.new( assembly_dir )
			server.generate_cert

			expect( server.public_key ).to match( /\A\p{Ascii}{40}\z/ )
		end


		it "doesn't raise an error if the cert already exists" do
			server = described_class.new( assembly_dir )
			server.generate_cert

			expect {
				server.generate_cert
			}.to_not raise_error
		end

	end


	describe "signal-handling" do

		before( :each ) do
			@server = described_class.new( assembly_dir )
			@server.setup_run_directory
			@server.generate_cert
			@server.create_database

			@server_thread = Thread.new do
				Thread.current.abort_on_exception = true
				@server.start
			end
		end

		after( :each ) do
			@server.stop
			@server_thread.kill unless @server_thread.join( 2 )
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

