#!/usr/bin/env rspec -cfd

require_relative '../spec_helper'

require 'tmpdir'
require 'assemblage/worker'


describe Assemblage::Worker do

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

			server_cert = CZTop::Certificate.new
			server_pubkey = server_cert.public_key

			described_class.setup_run_directory( assemblage_dir )
			Assemblage.use_run_directory( assemblage_dir )
			described_class.generate_cert
			described_class.add_server( 'tcp://127.0.0.1:12718', server_pubkey )

			@worker = described_class.new( server: 'tcp://127.0.0.1:12718' )

			@worker_thread = Thread.new do
				Thread.current.abort_on_exception = true
				@worker.run
			end
		end

		after( :each ) do
			@worker.stop if @worker
			@worker_thread.kill unless !@worker_thread || @worker_thread.join( 2 )
			Dir.chdir( @old_pwd )
		end


		it "stops when sent a TERM signal" do
			wait( 1 ).for { @worker.running? }.to be_truthy
			@worker.simulate_signal( :TERM )
			wait( 1 ).for { @worker.stopped? }.to be_truthy
		end


		it "stops when sent an INT signal" do
			wait( 1 ).for { @worker.running? }.to be_truthy
			@worker.simulate_signal( :INT )
			wait( 1 ).for { @worker.stopped? }.to be_truthy
		end


		it "stops when sent a HUP signal" do
			wait( 1 ).for { @worker.running? }.to be_truthy
			@worker.simulate_signal( :HUP )
			wait( 1 ).for { @worker.stopped? }.to be_truthy
		end

	end


end

