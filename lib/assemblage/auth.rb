# -*- ruby -*-
#encoding: utf-8

require 'configurability'
require 'loggability'

require 'assemblage' unless defined?( Assemblage )


module Assemblage::Auth
	extend Configurability,
	       Loggability

	# The name of the key on client certs that contains the name of the associated
	# worker.
	WORKER_NAME_KEY = 'worker-name'

	# The name of the key on repo certs that contains the URL of the associated
	# repository
	REPO_URL_KEY = 'repo-url'


	# Loggability API -- log to the Assemblage logger
	log_to :assemblage

	# Configurability API -- declare config settings
	configurability( 'assemblage.auth' ) do

		##
		# :singleton-method:
		# Configurable: the path to the directory that will store CURVE security certs.
		# If this is +nil+, an in-memory store will be used.
		setting :cert_store_dir do |dir|
			dir ? Pathname( dir ) : nil
		end

	end


	### Check the runtime environment for required setup (e.g., CURVE auth)
	def self::check_environment
		CZTop::Certificate.check_curve_availability
	end


	### Return a Pathname for the server cert if a cert_store_dir is configured.
	### Returns nil if it is not.
	def self::server_cert_path
		certdir = self.cert_store_dir or return nil
		return certdir + 'server'
	end


	### Return a Pathname for the directory that contains client certs if a
	### cert_store_dir is configured. Returns nil if it is not.
	def self::client_certs_path
		certdir = self.cert_store_dir or return nil
		return certdir + 'clients'
	end


	### Return the server (public+secret) cert as a CZTop::Certificate object.
	def self::server_cert
		if certpath = self.server_cert_path
			cert = CZTop::Certificate.load( certpath )
			self.log.info "Using server cert from %s: %s" %
				[ self.server_cert_path, cert.public_key ]
			return cert
		else
			cert = self.make_server_cert
			self.log.warn "No cert_store_dir set: using ephemeral server cert (%s)." %
				[ cert.public_key ]
			return cert
		end
	end


	### Return the server (public only) cert as a CZTop::Certificate object.
	def self::public_server_cert
		cert = self.server_cert
		return CZTop::Certificate.new_from( cert.public_key(format: :binary) )
	end


	### Returns +true+ if a server cert has been generated.
	def self::has_server_cert?
		return self.server_cert_path && self.server_cert_path.exist?
	end


	### Generate a new server cert and save it. Raises an exception if there is no
	### cert_store_dir configured or if there is already a server cert in it.
	def self::generate_server_cert
		cert_file = self.server_cert_path or raise "No server cert dir configured."
		raise "Server cert already exists at %s" % [ cert_file ] if cert_file.exist?

		cert_file.dirname.mkpath
		cert = self.make_server_cert
		cert.save( cert_file )

		return cert
	end


	### Generate a certificate and return it as a CZTop::Certificate.
	def self::make_server_cert
		cert = CZTop::Certificate.new
		cert[ 'name' ] = 'Assembly Server Cert'
		return cert
	end


	### Return the CZTop::Certificate (that includes the secret key) for the
	### specified +workername+ if it exists. Returns +nil+ if it doesn't.
	def self::client_cert( workername )
		dir = self.client_certs_path or return nil
		certpath = dir + workername
		return nil unless certpath.exist?
		return CZTop::Certificate.load( certpath )
	end


	### Look up the cert associated with the specified +public_key+ and return it if
	### it exists.
	def self::lookup_client_cert( public_key )
		return self.cert_store.lookup( public_key )
	end


	### Make a client cert for the given +workername+, save it in the certs dir if one
	### is configured, and return it as a CZTop::Certificate.
	def self::generate_client_cert( workername )
		raise ArgumentError, "invalid workername %p" % [ workername ] unless
			self.valid_workername?( workername )

		cert = CZTop::Certificate.new
		cert[ WORKER_NAME_KEY ] = workername

		if self.cert_store_dir
			self.client_certs_path.mkpath
			cert.save( self.client_certs_path + workername )
		end

		return cert
	end


	### Remove an existing client cert for the given +workername+ if it exists.
	def self::remove_client_cert( workername )
		raise ArgumentError, "invalid workername %p" % [ workername ] unless
			self.valid_workername?( workername )

		if self.client_certs_path
			public_cert = self.client_certs_path + workername
			public_cert.unlink
			secret_cert = self.client_certs_path + "#{workername}_secret"
			secret_cert.unlink
		end
	end


	### Returns +true+ if the specified +workername+ is valid.
	def self::valid_workername?( workername )
		return Assemblage::Worker.valid_workername?( workername )
	end


	### Given a client +cert+ (a CZTop::Certificate), return the associated worker
	### name.
	def self::workername_for_cert( cert )
		return cert[ WORKER_NAME_KEY ]
	end


	### Return a configured CZTop::CertStore pointing to the configured #data_dir
	def self::authenticator
		return @authenticator ||= begin
			self.log.info "Creating CURVE authenticator."
			auth = CZTop::Authenticator.new

			if certs_dir = self.client_certs_path
				self.log.info "Using client certs dir %s for auth." % [ certs_dir ]
				certs_dir.mkpath
				auth.curve( certs_dir.to_s )
			else
				self.log.warn "Using ALLOW_ANY client curve auth."
				auth.curve( CZTop::Authenticator::ALLOW_ANY )
			end

			auth
		end
	end


	### Return a configured CZTop::CertStore.
	def self::cert_store
		certs_dir = self.client_certs_path or raise "No client cert dir configured."
		return @certstore ||= CZTop::CertStore.new( certs_dir.to_s )
	end


	### Reset memoized objects in the class (mostly for testing).
	def self::reset
		if @authenticator
			@authenticator.actor.terminate
			@authenticator = nil
		end
		@certstore = nil
	end


end # module Assemblage::Auth
