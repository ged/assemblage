#!/usr/bin/env rspec -cfd

require_relative '../spec_helper'

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


		it "can generate a new server cert" do
			cert = described_class.generate_server_cert
			expect( cert ).to be_a( CZTop::Certificate )
			expect( described_class.cert_store_dir + 'server' ).to exist
			expect( described_class.cert_store_dir + 'server_secret' ).to exist
		end


		it "won't clobber an existing server cert" do
			described_class.generate_server_cert
			expect {
				described_class.generate_server_cert
			}.to raise_error( /already/i )
		end


		it "raises a sensible error when attempting to generate a cert without a cert_store_dir" do
			described_class.cert_store_dir = nil
			expect {
				described_class.generate_server_cert
			}.to raise_error( /no server cert dir/i )
		end


		it "can create an authenticator for client certs" do
			expect( described_class.authenticator ).to be_a( CZTop::Authenticator )
		end


		it "can create a certstore for its client certs" do
			expect( described_class.cert_store ).to be_a( CZTop::CertStore )
		end


		it "raises a sensible error when attempting to create a certstore without a cert_store_dir" do
			described_class.cert_store_dir = nil
			expect {
				described_class.cert_store
			}.to raise_error( /no client cert dir/i )
		end


		it "can generate client certs" do
			cert = described_class.generate_client_cert( 'readyplayer1' )
			expect( cert ).to be_a( CZTop::Certificate )
			expect( cert.public_key ).to_not be_empty
			expect( cert.secret_key ).to_not be_empty
			expect( cert[described_class::WORKER_NAME_KEY] ).to eq( 'readyplayer1' )
		end


		it "can look up a client cert by its public key" do
			cert = described_class.generate_client_cert( 'leeeeeroy' )
			cert2 = described_class.lookup_client_cert( cert.public_key )

			expect( cert2.public_key ).to eq( cert.public_key )
			expect( cert2[described_class::WORKER_NAME_KEY] ).to eq( 'leeeeeroy' )
		end

	end

end

