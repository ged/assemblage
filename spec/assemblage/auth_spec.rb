#!/usr/bin/env rspec -cfd

require_relative '../spec_helper'

require 'tmpdir'
require 'cztop'
require 'assemblage/auth'

describe Assemblage::Auth do

	before( :each ) do
		described_class.reset
		@test_data_dir = Dir.mktmpdir( ['assemblage-rspec-', '-data'] )
	end

	after( :each ) do
		FileUtils.remove_entry( @test_data_dir )
	end


	describe "zauth security" do

		before( :each ) do
			described_class.cert_store_dir = File.join( @test_data_dir, "certs" )
		end


		it "can generate a new local cert" do
			cert = described_class.generate_local_cert
			expect( cert ).to be_a( CZTop::Certificate )
			expect( described_class.cert_store_dir + 'local' ).to exist
			expect( described_class.cert_store_dir + 'local_secret' ).to exist
		end


		it "won't clobber an existing local cert" do
			described_class.generate_local_cert
			expect {
				described_class.generate_local_cert
			}.to raise_error( /already/i )
		end


		it "raises a sensible error when attempting to generate a cert without a cert_store_dir" do
			described_class.cert_store_dir = nil
			expect {
				described_class.generate_local_cert
			}.to raise_error( /no local cert dir/i )
		end


		it "can create an authenticator for remote certs" do
			expect( described_class.authenticator ).to be_a( CZTop::Authenticator )
		end


		it "can create a certstore" do
			expect( described_class.cert_store ).to be_a( CZTop::CertStore )
		end


		it "raises a sensible error when attempting to create a certstore without a cert_store_dir" do
			described_class.cert_store_dir = nil
			expect {
				described_class.cert_store
			}.to raise_error( /no remote cert dir/i )
		end


		it "can save remote certs given a name and a public key" do
			thirdparty_cert = CZTop::Certificate.new
			pubkey = thirdparty_cert.public_key

			cert = described_class.save_remote_cert( 'funkervogt', pubkey )

			expect( cert ).to be_a( CZTop::Certificate )
			expect( cert.public_key ).to_not be_empty
			expect( cert.secret_key ).to be_nil
			expect( described_class.client_name_for(cert) ).to eq( 'funkervogt' )
		end


		it "can look up a remote cert by its public key" do
			thirdparty_cert = CZTop::Certificate.new
			pubkey = thirdparty_cert.public_key

			described_class.save_remote_cert( 'adelios', pubkey )
			cert = described_class.lookup_remote_cert( pubkey )

			expect( cert ).to be_a( CZTop::Certificate )
			expect( cert.public_key ).to eq( pubkey )
			expect( described_class.client_name_for(cert) ).to eq( 'adelios' )
		end

	end

end

