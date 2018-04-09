#!/usr/bin/env rspec -cfd
#encoding: utf-8

require_relative 'spec_helper'

require 'rspec'
require 'assemblage'

describe Assemblage do


	it "has a VERSION constant" do
		expect( described_class::VERSION ).to match( /\A\d+\.\d+\.\d+/ )
	end


	describe "configurability" do

		before( :all ) do
			@original_config_env = ENV[ Assemblage::CONFIG_ENV ]
		end

		before( :each ) do
			ENV.delete( Assemblage::CONFIG_ENV )
		end

		after( :all ) do
			Configurability.reset
			ENV[ Assemblage::CONFIG_ENV ] = @original_config_env
		end


		it "can return the loaded configuration" do
			Configurability.configure_objects( Configurability.default_config )
			expect( described_class.config ).to be( Configurability.loaded_config )
		end


		it "knows whether or not the config has been loaded" do
			Configurability.configure_objects( Configurability.default_config )
			expect( described_class ).to be_config_loaded
			Configurability.reset
			expect( described_class ).to_not be_config_loaded
		end


		it "will load a local config file if it exists and none is specified" do
			config_object = double( "Configurability::Config object" )
			allow( config_object ).to receive( :[] ).with( :assemblage ).and_return( {} )

			expect( Configurability ).to receive( :gather_defaults ).
				and_return( {} )
			expect( Assemblage::LOCAL_CONFIG_FILE ).to receive( :exist? ).
				and_return( true )
			expect( Configurability::Config ).to receive( :load ).
				with( Assemblage::LOCAL_CONFIG_FILE, {} ).
				and_return( config_object )
			expect( config_object ).to receive( :install )

			Assemblage.load_config
		end


		it "will load a default config file if none is specified and there's no local config" do
			config_object = double( "Configurability::Config object" )
			allow( config_object ).to receive( :[] ).with( :assemblage ).and_return( {} )

			expect( Configurability ).to receive( :gather_defaults ).
				and_return( {} )
			expect( Assemblage::LOCAL_CONFIG_FILE ).to receive( :exist? ).
				and_return( false )
			expect( Configurability::Config ).to receive( :load ).
				with( Pathname.pwd + Assemblage::DEFAULT_CONFIG_FILE, {} ).
				and_return( config_object )
			expect( config_object ).to receive( :install )

			Assemblage.load_config
		end


		it "will load a config file given in an environment variable" do
			ENV['ASSEMBLAGE_CONFIG'] = '/usr/local/etc/config.yml'

			config_object = double( "Configurability::Config object" )
			allow( config_object ).to receive( :[] ).with( :assemblage ).and_return( {} )

			expect( Configurability ).to receive( :gather_defaults ).
				and_return( {} )
			expect( Configurability::Config ).to receive( :load ).
				with( '/usr/local/etc/config.yml', {} ).
				and_return( config_object )
			expect( config_object ).to receive( :install )

			Assemblage.load_config
		end


		it "will load a config file and install it if one is given" do
			config_object = double( "Configurability::Config object" )
			allow( config_object ).to receive( :[] ).with( :assemblage ).and_return( {} )

			expect( Configurability ).to receive( :gather_defaults ).
				and_return( {} )
			expect( Configurability::Config ).to receive( :load ).
				with( 'a/configfile.yml', {} ).
				and_return( config_object )
			expect( config_object ).to receive( :install )

			Assemblage.load_config( 'a/configfile.yml' )
		end


		it "will override default values when loading the config if they're given" do
			config_object = double( "Configurability::Config object" )
			allow( config_object ).to receive( :[] ).with( :assemblage ).and_return( {} )

			expect( Configurability ).to_not receive( :gather_defaults )
			expect( Configurability::Config ).to receive( :load ).
				with( 'a/different/configfile.yml', {database: {dbname: 'test'}} ).
				and_return( config_object )
			expect( config_object ).to receive( :install )

			Assemblage.load_config( 'a/different/configfile.yml', database: {dbname: 'test'} )
		end

	end

end

