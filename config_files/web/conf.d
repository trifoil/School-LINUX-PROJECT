# Apache vhost configuration for a static html server.
# It manages SSL connections including certificates.
# Initially, a self-signed certificate is active. 
# Incoming http traffic is automatically redirected to https.
# Version 2.1

#==> To adjust in vi/vim copy and adjust to the vi command line:
# : %s/SHORT_DESCR/real_short_descr/g	e.g. my-domain.org production production server
# : %s/FQN_NAME/your_domain/g		e.g. my-domain.org
# : %s/BASE_NAME/your_shortname/g	e.g. my-domain
# : %s/OPTIONAL_ALIAS/your_alias/g	e.g. www.my-domain.org
# afterwards delete these lines


# Certificates are managed by Apache md module.
#==> To activate, remove the leading '#' character and comment out 
# the default distribution provided certificates further down. 
#==> Adjust the mail address as appropriate!
#MDContactEmail root@FQN_NAME
#MDCertificateAgreement accepted
#MDomain FQN_NAME 

<VirtualHost *:443>
	# Secure virtual WEB host configuration for 
	# SHORT_DESCR

	# The site can be accessed by https/ssl only. Without a valid certificate
	# you have to use a self-signed certificate as a quick temporary fix.

	ServerName      FQN_NAME
	ServerAlias	OPTIONAL_ALIAS

	#==> Adjust the mail address as appropriate!
	ServerAdmin     root@localhost

	# ##########################################################################
	# NOTE: We re-route everything from the insecure site to this secure site!
	# ##########################################################################

	# Optional: Ensure that all registered domain names are rewritten to the
	# official base name
	#RewriteEngine   On
	#RewriteCond     %{HTTP_HOST}    !^FQN_NAME [NC]
	#RewriteCond     %{HTTP_HOST}    !^$
	#RewriteRule     ^(.*)$          https://FQN_NAME$1  [R=301,L]

	# ====================================================================
	# Certificates configuration
	# ====================================================================
	SSLEngine on
	# We rely on Fedora's systemwide configuration of SSL security.

	# By default, certificates are managed by Apache md module (see above)
	# In this case, no certificates needs bo be configured here.
	# Otherwise, insert proper certificate configuration here.

	# DEFAULT distribution provided, needed for initial startup.
	#==> Comment OUT when module md created a certificate or you use custom
	# certificates.
	SSLCertificateFile	/etc/pki/tls/certs/localhost.crt
	SSLCertificateKeyFile	/etc/pki/tls/private/localhost.key

	# LetsEncrypt certificates managed by certbot (NOT by module md!)
	#SSLCertificateFile      /etc/letsencrypt/live/DOMAIN_NAME/cert.pem
	#SSLCertificateKeyFile   /etc/letsencrypt/live/DOMAIN_NAME/privkey.pem
	#SSLCertificateChainFile /etc/letsencrypt/live/DOMAIN_NAME/chain.pem

	# ===============================================================
	# Directory Locations
	# ===============================================================
	DirectoryIndex	index.html
	DocumentRoot	/srv/BASE_NAME/htdocs
	# Specific to default 2.4 configuration:
	# Enable access to server-specific base file location
	<Directory "/srv/BASE_NAME">
		AllowOverride None
		# Allow open access:
		Require all granted
	</Directory>
	# Further relax access to the default document root
	<Directory "/srv/BASE_NAME/htdocs">
		#
		# Possible values for the Options directive are "None", "All",
		# or any combination of:
		#   Indexes Includes FollowSymLinks SymLinksifOwnerMatch ExecCGI MultiViews
		#
		# Note that "MultiViews" must be named *explicitly* --- "Options All"
		# doesn't give it to you.
		#
		# The Options directive is both complicated and important.  Please see
		# http://httpd.apache.org/docs/2.4/mod/core.html#options
		# for more information.
		#
		Options Indexes FollowSymLinks

		#
		# AllowOverride controls what directives may be placed in .htaccess files.
		# It can be "All", "None", or any combination of the keywords:
		#   Options FileInfo AuthConfig Limit
		#
		AllowOverride None

		#
		# Controls who can get stuff from this server:
		# Allow open access:
		Require all granted

	</Directory>


	# ===============================================================
	# Optional: Protect access to start page (and subsequent pages) 
	# ==>       Ensure you created the additional auth.d directory 
	#           including SELinux labels
	# ===============================================================
	#<Location />
	#	AuthType Basic
	#	AuthName "Access start page"
	#	AuthUserFile /srv/BASE_NAME/auth.d/htuser
	#	Require valid-user
	#</Location>


	# ===============================================================
	# Optional: Configure webDAV access 
	#==>        Ensure you created the additional davlock directory 
	#           including SELinux labels
	# ===============================================================
	#DavLockDB /srv/SERVER_SHORT_NAME/davlock/dav_lock_db

	#<Location /dav>
	#	DAV On
	#	ForceType text/plain

	#	Order Allow,Deny
	#	Allow from all
	#	Options all
	#	DirectoryIndex none

		# Optional: Protect basic dav page (and all subsequent page)
		#AuthType Basic
		#AuthName "Application Server WebDAV access"
		#AuthUserFile /srv/SERVER_SHORT_NAME/auth.d/htdavuser
		#Require valid-user
	#</Location>


	# ===============================================================
	# Logging configuration
	# ===============================================================
	# Use separate log files for the SSL virtual host; note that LogLevel
	# is not inherited from httpd.conf.
	# NOTE: fail2ban searches for ~/logs/*access_log and  ~/logs/*error_log
	#       to access log files to watch and analyze!
	ErrorLog        logs/BASE_NAME-ssl_error_log
	CustomLog       logs/BASE_NAME-ssl_access_log combined
	LogLevel warn

</VirtualHost>

<VirtualHost *:80>
	# INSECURE virtual WEB host configuration for 
	# SHORT_DESCR

	# NOTE: Everything from the insecure port 80 is redirected to this instance'
	#       SECURE site

	ServerName      FQN_NAME
	ServerAlias	OPTIONAL_ALIAS

	ServerAdmin     root@FQN_NAME

	# ##########################################################################
	# NOTE: We re-route everything to the secure site! 
	#       We retain all aliase names for now.
	#       There is no need for an exception for Let's Encrypt anymore. 
	#       Version 2.x can deal with self-signed certificates and https
	# ##########################################################################
	RewriteEngine   On
	RewriteRule	(.*)	https://%{HTTP_HOST}%{REQUEST_URI} [R=301,L]


	# ===============================================================
	# Logging configuration
	# ===============================================================
	# Use separate log files for the SSL virtual host; note that LogLevel
	# is not inherited from httpd.conf.
	# NOTE: fail2ban searches for ~/logs/*access_log and  ~/logs/*error_log
	#       to access log files to watch and analyze!
	ErrorLog        logs/BASE_NAME-error_log
	CustomLog       logs/BASE_NAME-access_log combined

</VirtualHost>
