# -*- ruby -*-
#encoding: utf-8

require 'cztop'
require 'configurability'
require 'loggability'

require 'assemblage' unless defined?( Assemblage )
require 'assemblage/mixins'


module Assemblage::Auth
	extend Configurability,
	       Loggability,
	       Assemblage::MethodUtilities

	# The name of the metadata field that stores the server/worker/repo name
	# associated with a remote key
	CLIENT_NAME_KEY = 'client_name'

	# Regexp for testing client names for validity
	CLIENT_NAME_PATTERN = /\A[a-z][\w\-]+\z/i

	# The minimum number of characters for a client name
	NAME_MIN_LENGTH = 3

	# The amximum number of characters for a client name
	NAME_MAX_LENGTH = 35


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
		warn "ZeroMQ was built without CURVE, so authentication will be broken" unless
			CZMQ::FFI::Zsys.has_curve
	end


	### Return a Pathname for the local cert if a cert_store_dir is configured.
	### Returns nil if it is not.
	def self::local_cert_path
		certdir = self.cert_store_dir or return nil
		return certdir + 'local'
	end


	### Return a Pathname for the directory that contains client certs if a
	### cert_store_dir is configured. Returns nil if it is not.
	def self::remote_certs_path
		certdir = self.cert_store_dir or return nil
		return certdir + 'remote'
	end


	### Return the local (public+secret) cert as a CZTop::Certificate object.
	def self::local_cert
		if certpath = self.local_cert_path
			cert = CZTop::Certificate.load( certpath )
			self.log.info "Using local cert from %s: %s" %
				[ self.local_cert_path, cert.public_key ]
			return cert
		else
			cert = self.make_local_cert
			self.log.warn "No cert_store_dir set: using ephemeral local cert (%s)." %
				[ cert.public_key ]
			return cert
		end
	end


	### Return the local (public only) cert as a CZTop::Certificate object.
	def self::public_local_cert
		cert = self.local_cert
		return CZTop::Certificate.new_from( cert.public_key(format: :binary) )
	end


	### Returns +true+ if a local cert has been generated.
	def self::has_local_cert?
		return self.local_cert_path && self.local_cert_path.exist?
	end


	### Generate a new local cert and save it. Raises an exception if there is no
	### cert_store_dir configured or if there is already a local cert in it.
	def self::generate_local_cert
		cert_file = self.local_cert_path or raise "No local cert dir configured."
		raise "Server cert already exists at %s" % [ cert_file ] if cert_file.exist?

		cert_file.dirname.mkpath
		cert = self.make_local_cert
		cert.save( cert_file )

		return cert
	end


	### Generate a certificate and return it as a CZTop::Certificate.
	def self::make_local_cert
		cert = CZTop::Certificate.new
		cert[ 'name' ] = 'Assembly Local Cert'
		return cert
	end


	### Return the CZTop::Certificate (public key only) for the specified
	### +client_name+ if it exists. Returns +nil+ if it doesn't.
	def self::remote_cert( client_name )
		dir = self.remote_certs_path or return nil
		certpath = dir + client_name
		return nil unless certpath.exist?
		return CZTop::Certificate.load( certpath )
	end


	### Look up the cert associated with the specified +public_key+ and return it if
	### it exists.
	def self::lookup_remote_cert( public_key )
		return self.cert_store.lookup( public_key )
	end


	### Returns +true+ if a remote cert has been saved for the specified +client_name+.
	def self::has_remote_cert?( client_name )
		raise ArgumentError, "invalid client_name %p" % [ client_name ] unless
			self.valid_client_name?( client_name )

		certfile = self.remote_certs_path + client_name

		return certfile.exist?
	end


	### Make a remote cert for the given +client_name+, save it in the certs dir if one
	### is configured, and return it as a CZTop::Certificate.
	def self::save_remote_cert( client_name, public_key )
		raise ArgumentError, "invalid client name %p" % [ client_name ] unless
			self.valid_client_name?( client_name )

		cert = CZTop::Certificate.new_from( public_key )
		cert[ CLIENT_NAME_KEY ] = client_name

		if self.cert_store_dir
			self.remote_certs_path.mkpath
			cert.save( self.remote_certs_path + client_name )
		end

		return cert
	end


	### Remove an existing remote cert for the given +client_name+ if it exists.
	def self::remove_remote_cert( client_name )
		raise ArgumentError, "invalid client_name %p" % [ client_name ] unless
			self.valid_client_name?( client_name )

		if self.remote_certs_path
			public_cert = self.remote_certs_path + client_name
			public_cert.unlink
		end
	end


	### Returns +true+ if the specified +name+ is valid for a client's name.
	def self::valid_client_name?( name )
		return CLIENT_NAME_PATTERN.match?( name ) &&
			( NAME_MIN_LENGTH .. NAME_MAX_LENGTH ).cover?( name.length )
	end


	### Given a remote +cert+ (a CZTop::Certificate), return the associated client
	### name.
	def self::client_name_for( cert )
		return cert[ CLIENT_NAME_KEY ]
	end
	singleton_method_alias :client_name_for_cert, :client_name_for


	### Return a configured CZTop::CertStore pointing to the configured #data_dir
	def self::authenticator
		return @authenticator ||= begin
			self.log.info "Creating CURVE authenticator."
			auth = CZTop::Authenticator.new

			if certs_dir = self.remote_certs_path
				self.log.info "Using remote certs dir %s for auth." % [ certs_dir ]
				certs_dir.mkpath
				auth.curve( certs_dir.to_s )
			else
				self.log.warn "Using ALLOW_ANY remote curve auth."
				auth.curve( CZTop::Authenticator::ALLOW_ANY )
			end

			auth
		end
	end


	### Return a configured CZTop::CertStore.
	def self::cert_store
		certs_dir = self.remote_certs_path or raise "No remote cert dir configured."
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
