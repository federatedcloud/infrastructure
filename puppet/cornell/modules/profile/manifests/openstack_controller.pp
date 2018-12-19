class profile::openstack_controller (
	$admin_email = '',
	$admin_password = 'changeme',
	$high_availability = false,
	$management_interface,
	$provider_interface,
	$public_interface,
	$ha_cluster_name = 'redcloud-os',
	$ha_hostname = 'redcloud.cac.cornell.edu',
	$ha_vip = '',
	$ha_host_ips = undef,
	$ha_host_names = undef,
	$galera_master = false,
	$pacemaker_password = 'changeme',
	$ssl_cert	  = '',
	$ssl_key 	  = '',
	$ssl_chain    = '',
	$region       = 'RegionOne',
	$availability_zone = 'nova',
	$self_service_network = true,
	$rabbitmq_admin_password = 'changeme',
	$rabbitmq_user = 'openstack',
	$rabbitmq_password = 'changeme',
	$rabbitmq_erlang_cookie,
	$memcached_servers = undef,
	$glance_keystone_password = 'changeme',
	$glance_keystone_email = '',
	$db_keystone_admin_password = 'changeme',
	$keystone_admin_token,
	$keystone_ldap_support = false,
	$keystone_ldap_url,
	$keystone_ldap_bind_user,
	$keystone_ldap_bind_password,
	$keystone_ldap_suffix,
	$keystone_ldap_user_tree_dn,
	$keystone_ldap_group_tree_dn,
	$keystone_federation_globus_client_id,
	$keystone_federation_globus_client_secret,
	$db_glance_admin_password = 'changeme',
	$glance_backend_pool = 'images',
	$glance_ceph_client = 'glance',
	$glance_ceph_client_key = '',
	$db_nova_admin_password = 'changeme',
	$db_nova_api_admin_password = 'changeme',
	$db_nova_placement_admin_password = 'changeme',
	$nova_keystone_email = '',
	$nova_keystone_password = 'changeme',
	$nova_placement_keystone_email = '',
	$nova_placement_keystone_password = 'changeme',
	$neutron_metadata_proxy_shared_secret = 'changeme',
	$cinder_keystone_password = 'changeme',
	$cinder_keystone_email = '',
	$db_cinder_admin_password = 'changeme',
	$cinder_backend_pool = 'volumes',
	$cinder_ceph_client = 'cinder',
	$cinder_ceph_client_key = '',
	$rbd_secret_uuid = '',
	$db_neutron_admin_password = 'changeme',
	$neutron_keystone_password = 'changeme',
	$neutron_keystone_email = '',
	$horizon_secret_key,
	$ceph_keystone_password = 'changeme',
	$radosgw_hostnames,
	$radosgw_ips,
) {
	#
	# IP addresses
	#
	$management_ip = $facts['networking']['interfaces']["$management_interface"]['ip']
	$public_ip = $facts['networking']['interfaces']["$public_interface"]['ip']
	$controller_ip = $facts['networking']['fqdn']
	$overlay_ip = $facts['networking']['fqdn']

	$keystone_ip = $controller_ip
	$glance_ip = $controller_ip
	$memcached_ip = $controller_ip
	$mysql_ip = $controller_ip
	$rabbitmq_ip = $controller_ip
	$nova_ip = $controller_ip
	$neutron_ip = $controller_ip
	$cinder_ip = $controller_ip
	$panko_ip = $controller_ip
	$gnocchi_ip = $controller_ip
	$ceilometer_ip = $controller_ip
	$horizon_bind_address = $public_ip
	
	if $high_availability {
		$ha_backend_names = split($ha_host_names, ",")
		$ha_backend_ips = split($ha_host_ips, ",")
	
		# MariaDB
		$mysql_publish_ip = $ha_vip
		# Keystone
		$keystone_public_bind_host = $keystone_ip
		$keystone_internal_bind_host = $keystone_ip
		$keystone_admin_bind_host = $keystone_ip
		$keystone_advertise_public_bind_host = $ha_hostname
		$keystone_advertise_internal_bind_host = $ha_hostname
		$keystone_advertise_admin_bind_host = $ha_hostname
		# Glance
		$glance_public_bind_host = $glance_ip
		$glance_internal_bind_host = $glance_ip
		$glance_admin_bind_host = $glance_ip
		$glance_advertise_public_bind_host = $ha_hostname
		$glance_advertise_internal_bind_host = $ha_hostname
		$glance_advertise_admin_bind_host = $ha_hostname
		# Glance Registry
		$glance_registry_public_bind_host = $glance_ip
		$glance_registry_internal_bind_host = $glance_ip
		$glance_registry_admin_bind_host = $glance_ip
		$glance_registry_advertise_public_bind_host = $ha_hostname
		$glance_registry_advertise_internal_bind_host = $ha_hostname
		$glance_registry_advertise_admin_bind_host = $ha_hostname
		# Nova
		$nova_public_bind_host = $nova_ip
		$nova_internal_bind_host = $nova_ip
		$nova_admin_bind_host = $nova_ip
		$nova_advertise_public_bind_host = $ha_hostname
		$nova_advertise_internal_bind_host = $ha_hostname
		$nova_advertise_admin_bind_host = $ha_hostname
		# Nova Placement
		$nova_placement_public_bind_host = $nova_ip
		$nova_placement_internal_bind_host = $nova_ip
		$nova_placement_admin_bind_host = $nova_ip
		$nova_placement_advertise_public_bind_host = $ha_hostname
		$nova_placement_advertise_internal_bind_host = $ha_hostname
		$nova_placement_advertise_admin_bind_host = $ha_hostname
		# Cinder
		$cinder_public_bind_host = $cinder_ip
		$cinder_internal_bind_host = $cinder_ip
		$cinder_admin_bind_host = $cinder_ip
		$cinder_advertise_public_bind_host = $ha_hostname
		$cinder_advertise_internal_bind_host = $ha_hostname
		$cinder_advertise_admin_bind_host = $ha_hostname
		# Neutron
		$neutron_public_bind_host = $neutron_ip
		$neutron_internal_bind_host = $neutron_ip
		$neutron_admin_bind_host = $neutron_ip
		$neutron_advertise_public_bind_host = $ha_hostname
		$neutron_advertise_internal_bind_host = $ha_hostname
		$neutron_advertise_admin_bind_host = $ha_hostname

		$amqp_durable_queues = false
		$rabbit_ha_queues = true
		$ha_rabbit_list = $ha_backend_ips.map |$node| {"${rabbitmq_user}:${rabbitmq_password}@$node:5672" }.join(",")
		$rabbitmq_url = "rabbit://${ha_rabbit_list}"
		$memcached_url = $ha_backend_ips.map |$node| {"${node}:11211"}.join(",")
		# Wants an array
		$horizon_cache_servers = $ha_backend_ips
	}
	else {
		# MariaDB
		$mysql_publish_ip = $mysql_ip

		# Keystone
		$keystone_public_bind_host = $keystone_ip
		$keystone_internal_bind_host = $keystone_ip
		$keystone_admin_bind_host = $keystone_ip
		$keystone_advertise_public_bind_host = $keystone_ip
		$keystone_advertise_internal_bind_host = $keystone_ip
		$keystone_advertise_admin_bind_host = $keystone_ip
		# Glance
		$glance_public_bind_host = $glance_ip
		$glance_internal_bind_host = $glance_ip
		$glance_admin_bind_host = $glance_ip
		$glance_advertise_public_bind_host = $glance_ip
		$glance_advertise_internal_bind_host = $glance_ip
		$glance_advertise_admin_bind_host = $glance_ip
		# Glance Registry
		$glance_registry_public_bind_host = $glance_ip
		$glance_registry_internal_bind_host = $glance_ip
		$glance_registry_admin_bind_host = $glance_ip
		$glance_registry_advertise_public_bind_host = $glance_ip
		$glance_registry_advertise_internal_bind_host = $glance_ip
		$glance_registry_advertise_admin_bind_host = $glance_ip
		# Nova
		$nova_public_bind_host = $nova_ip
		$nova_internal_bind_host = $nova_ip
		$nova_admin_bind_host = $nova_ip
		$nova_advertise_public_bind_host = $nova_ip
		$nova_advertise_internal_bind_host = $nova_ip
		$nova_advertise_admin_bind_host = $nova_ip
		# Nova Placement
		$nova_placement_public_bind_host = $nova_ip
		$nova_placement_internal_bind_host = $nova_ip
		$nova_placement_admin_bind_host = $nova_ip
		$nova_placement_advertise_public_bind_host = $nova_ip
		$nova_placement_advertise_internal_bind_host = $nova_ip
		$nova_placement_advertise_admin_bind_host = $nova_ip
		# Cinder
		$cinder_public_bind_host = $cinder_ip
		$cinder_internal_bind_host = $cinder_ip
		$cinder_admin_bind_host = $cinder_ip
		$cinder_advertise_public_bind_host = $cinder_ip
		$cinder_advertise_internal_bind_host = $cinder_ip
		$cinder_advertise_admin_bind_host = $cinder_ip
		# Neutron
		$neutron_public_bind_host = $neutron_ip
		$neutron_internal_bind_host = $neutron_ip
		$neutron_admin_bind_host = $neutron_ip
		$neutron_advertise_public_bind_host = $neutron_ip
		$neutron_advertise_internal_bind_host = $neutron_ip
		$neutron_advertise_admin_bind_host = $neutron_ip
		
		$rabbitmq_url = os_transport_url({
			'transport' => 'rabbit',
			'host'      => $rabbitmq_ip,
			'port'      => '5672',
			'username'  => $rabbitmq_user,
			'password'  => $rabbitmq_password,
		})
		$amqp_durable_queues = false
		$rabbit_ha_queues = false

		$memcached_url = "${memcached_ip}:11211"
		$horizon_cache_servers = $memcached_ip
	}

	#
	# Service Endpoint URLs
	#
	$keystone_public_url = "https://${keystone_advertise_public_bind_host}:8770"
	$keystone_admin_url = "https://${keystone_advertise_admin_bind_host}:35357"
	$keystone_internal_url = "https://${keystone_advertise_internal_bind_host}:8770"

	$glance_public_url = "https://${glance_advertise_public_bind_host}:9292"
	$glance_admin_url = "https://${glance_advertise_admin_bind_host}:9292"
	$glance_internal_url = "https://${glance_advertise_internal_bind_host}:9292"

	$nova_public_url = "http://${nova_advertise_public_bind_host}:8774/v2.1"
	$nova_admin_url = "http://${nova_advertise_admin_bind_host}:8774/v2.1"
	$nova_internal_url = "http://${nova_advertise_internal_bind_host}:8774/v2.1"

	$nova_placement_public_url = "https://${nova_placement_advertise_public_bind_host}:8778"
	$nova_placement_admin_url = "https://${nova_placement_advertise_admin_bind_host}:8778"
	$nova_placement_internal_url = "https://${nova_placement_advertise_internal_bind_host}:8778"

	$neutron_public_url = "https://${neutron_advertise_public_bind_host}:9696"
	$neutron_admin_url = "https://${neutron_advertise_admin_bind_host}:9696"
	$neutron_internal_url = "https://${neutron_advertise_internal_bind_host}:9696"

	$cinder_v1_public_url = "https://${cinder_advertise_public_bind_host}:8776/v1/%(project_id)s"
	$cinder_v1_admin_url = "https://${cinder_advertise_admin_bind_host}:8776/v1/%(project_id)s"
	$cinder_v1_internal_url = "https://${cinder_advertise_internal_bind_host}:8776/v1/%(project_id)s"
	$cinder_v2_public_url = "https://${cinder_advertise_public_bind_host}:8776/v2/%(project_id)s"
	$cinder_v2_admin_url = "https://${cinder_advertise_admin_bind_host}:8776/v2/%(project_id)s"
	$cinder_v2_internal_url = "https://${cinder_advertise_internal_bind_host}:8776/v2/%(project_id)s"
	$cinder_v3_public_url = "https://${cinder_advertise_public_bind_host}:8776/v3/%(project_id)s"
	$cinder_v3_admin_url = "https://${cinder_advertise_admin_bind_host}:8776/v3/%(project_id)s"
	$cinder_v3_internal_url = "https://${cinder_advertise_internal_bind_host}:8776/v3/%(project_id)s"
	$swift_public_url = "https://${ha_hostname}:8443/swift/v1"
	$swift_admin_url = "https://${ha_hostname}:8443/swift/v1"
	$swift_internal_url = "https://${ha_hostname}:8443/swift/v1"

	#
	# remove NetworkManager and firewalld
	#
	service { 'NetworkManager':
		ensure => 'stopped',
	}
	package { 'NetworkManager':
		ensure => 'purged',
	}

	class { 'openstacklib::openstackclient': }

	#
	# Configure rabbitmq
	#
	if $high_availability {
        $config_cluster = true
        $cluster_nodes = $ha_backend_names
        $wipe_db_on_cookie_change = true
        # Lots of problems if you change this on an existing queue
        # Must stop all services on all nodes, then
        #  rabbitmqctl stop_app
        #  rabbitmqctl reset
        #  rabbitmqctl start_app
        # then run puppet to recreate the queues and start the services

        rabbitmq_policy { 'HA@/':
           pattern    => '^(?!amq.).*',
           priority   => 0,
           applyto    => 'all',
           definition => {
              'ha-mode'      => 'all',
              'ha-sync-mode' => 'automatic',
           },
        }

        $tcp_keepalive = true
    }
	else {
        $config_cluster = false
        $cluster_nodes = []
        $wipe_db_on_cookie_change = false
    }

	
	class { 'rabbitmq':
		delete_guest_user => true,
        config_cluster           => $config_cluster,
        cluster_nodes            => $cluster_nodes,
        cluster_node_type        => 'ram',
        erlang_cookie            => $rabbitmq_erlang_cookie,
        wipe_db_on_cookie_change => $wipe_db_on_cookie_change,
        tcp_keepalive         => $tcp_keepalive,
		port => '5672',
	}
	rabbitmq_vhost { '/':
		provider => 'rabbitmqctl',
		require  => Class['::rabbitmq'],
	}
	profile::openstack_controller::mq_user { 'admin':
		password => $rabbitmq_admin_password,
		admin    => true,
	}
	profile::openstack_controller::mq_user { "$rabbitmq_user":
		password => $rabbitmq_password,
		before   => [ Anchor['keystone::service::begin'], Anchor['glance::service::begin'], Anchor['nova::service::begin'], Anchor['cinder::service::begin'], ],
	}

	# 
	# Configure Ceph
	#
	package { 'ceph-common':
		ensure => present,
	}
	file { '/etc/ceph/ceph.conf':
		ensure => file,
		owner  => 'root',
		group  => 'root',
		mode   => '0444',
		source => 'puppet:///modules/cac_ceph_client/ceph.conf',
	}
	file { '/etc/ceph/ceph.client.glance.keyring':
		ensure => file,
		owner  => 'glance',
		group  => 'root',
		mode   => '0400',
		content => epp( 'cac_ceph_client/client.keyring.epp',
						{ client_name => $glance_ceph_client,
						  client_key => $glance_ceph_client_key, } ),
	}
	file { '/etc/ceph/ceph.client.cinder.keyring':
		ensure => file,
		owner  => 'cinder',
		group  => 'root',
		mode   => '0400',
		content => epp( 'cac_ceph_client/client.keyring.epp',
					{ client_name => $cinder_ceph_client,
					  client_key => $cinder_ceph_client_key, } ),
	}

    #
    # Configure tuned
    #
	class { 'tuned':
		profile => 'latency-performance',
	}

	#
	# Network tuning
 	#
	file { '/etc/sysctl.d/50-openstack.conf':
		ensure => file,
		owner  => 'root',
		group  => 'root',
		mode   => '0644',
		source => 'puppet:///modules/profile/sysctl.d/50-openstack.conf'
	}
    exec { 'sysctl':
		command     => '/usr/sbin/sysctl --system',
		subscribe   => File['/etc/sysctl.d/50-openstack.conf'], 
		refreshonly => true,
	}


	# 
	# Keystone configurations
	#
	# Configure MySQL database for keystone
	mysql::db { 'keystone':
		ensure   => 'present',
		user     => 'keystone_admin',
		password => $db_keystone_admin_password,
		host     => '%',
		grant    => ['all'],
	}->
	class { 'keystone':
		debug                      => false,
		admin_token                => $keystone_admin_token,
		enabled                    => true,
		catalog_type               => 'sql',
		enable_credential_setup    => true,
		public_port                => '8770',
		admin_password             => $admin_password,
		database_connection        => "mysql+pymysql://keystone_admin:${db_keystone_admin_password}@${mysql_publish_ip}/keystone?charset=utf8",
		admin_endpoint             => $keystone_admin_url,
		public_endpoint            => $keystone_public_url,
		rabbit_use_ssl             => false,
		rabbit_ha_queues           => $rabbit_ha_queues,
		default_transport_url      => $rabbitmq_url,
		notification_transport_url => $rabbitmq_url,
		keystone_user              => 'keystone',
		keystone_group             => 'keystone',
		enable_ssl                 => false,
		fernet_max_active_keys     => '5',
		service_name               => 'httpd',
		using_domain_config        => true,
	}
	class { '::keystone::wsgi::apache':
		bind_host => $facts['networking']['ip'],
		ssl       => false,
		public_port => '8770',
		workers   => 5,
	}

	# Adds the admin credentials to keystone
	class { 'keystone::roles::admin':
		email          => $admin_email,
		password       => $admin_password,
		admin          => 'admin',
		admin_tenant   => 'admin',
		service_tenant => 'services',
	}

	if $keystone_ldap_support {
		# Configures LDAP authentication
		keystone_domain_config {
			'cac::identity/driver': value                  => 'ldap';
			'cac::ldap/url': value                         => $keystone_ldap_url;
			'cac::ldap/user': value                        => $keystone_ldap_bind_user;
			'cac::ldap/password': value                    => $keystone_ldap_bind_password;
			'cac::ldap/suffix': value                      => $keystone_ldap_suffix;
			'cac::ldap/query_scope': value                 => 'sub';
			'cac::ldap/user_objectclass': value            => 'person';
			'cac::ldap/user_tree_dn': value                => $keystone_ldap_user_tree_dn;
			'cac::ldap/user_filter': value                 => '(rsCacEucaEnable=TRUE)';
			'cac::ldap/group_filter': value                => '(rsCacEucaEnable=TRUE)';
			'cac::ldap/user_id_attribute': value           => 'sAMAccountName';
			'cac::ldap/user_name_attribute': value         => 'sAMAccountName';
			'cac::ldap/user_pass_attribute': value         => '';
			'cac::ldap/user_description_attribute': value  => 'description';
			'cac::ldap/user_mail_attribute': value         => 'mail';
			'cac::ldap/user_allow_create': value           => false;
			'cac::ldap/user_allow_update': value           => false;
			'cac::ldap/user_allow_delete': value           => false;
			'cac::ldap/user_enabled_attribute': value      => 'userAccountControl';
			'cac::ldap/user_enabled_mask': value           => '2';
			'cac::ldap/user_enabled_default': value        => '512';
			'cac::ldap/user_attribute_ignore': value       => 'password,tenant_id,tenants';
			'cac::ldap/group_tree_dn': value             => $keystone_ldap_group_tree_dn;
			'cac::ldap/group_objectclass': value         => 'group';
			'cac::ldap/group_id_attribute': value        => 'cn';
			'cac::ldap/group_member_attribute': value    => 'member';
			'cac::ldap/group_name_attribute': value      => 'name';
			'cac::ldap/group_allow_create': value        => false;
			'cac::ldap/group_allow_update': value        => false;
			'cac::ldap/group_allow_delete': value        => false;
			'cac::ldap/use_tls': value                     => false;
			'cac::credential/driver': value                => 'sql';
			'cac::assignment/driver': value                => 'sql';
		}
		keystone_domain { 'cac':
			ensure  => 'present',
			enabled => true,
		}
	}

	class { 'keystone::federation::openidc':
		methods                          => ['password','token','oauth1','openidc','saml2',],
		idp_name                      => 'globus',
		openidc_provider_metadata_url => 'https://auth.globus.org/.well-known/openid-configuration',
		openidc_client_id             => $keystone_federation_globus_client_id,
		openidc_client_secret         => $keystone_federation_globus_client_secret,
		openidc_response_type               => 'code',
	}
	keystone_config {
		'federation/remote_id_attribute': value   => 'HTTP_OIDC_ISS';
		'federation/trusted_dashboard': value     => 'https://redcloud.cac.cornell.edu/dashboard/auth/websso/';
		'federation/federated_domain_name': value => 'globus';
	}

	# Installs the service user endpoint
	class { 'keystone::endpoint':
		public_url   => $keystone_public_url,
		admin_url    => $keystone_admin_url,
		internal_url => $keystone_internal_url,
		region       => $region,
		version      => 'v3',
	}
	include keystone::disable_admin_token_auth

	class { 'openstack_extras::auth_file':
		password          => $admin_password,
		auth_url          => "$keystone_admin_url/v3",
		user_domain       => 'default',
		project_domain    => 'default',
		region_name => $region,
		project_name      => 'admin',
		cinder_endpoint_type => 'internalURL',
		glance_endpoint_type => 'internalURL',
		keystone_endpoint_type => 'internalURL',
		nova_endpoint_type => 'internalURL',
		neutron_endpoint_type => 'internalURL',
	}

	# Enable memcached
	class { 'memcached': 
		listen_ip => '0.0.0.0';
	}	

	#
	# Glance configurations
	# 
	class { 'glance::api::authtoken':
		password     => $glance_keystone_password,
		auth_url     => $keystone_admin_url,
		auth_uri     => $keystone_internal_url,
		auth_version => 'v3',
		memcached_servers  => $memcached_servers,
	}

	class { 'glance::registry::authtoken':
		password => $glance_keystone_password,
		auth_url => $keystone_admin_url,
		auth_uri => $keystone_internal_url,
		user_domain_name => 'default',
		project_domain_name => 'default',
	}

	class { 'glance::api':
		database_connection => "mysql+pymysql://glance_admin:${db_glance_admin_password}@${mysql_publish_ip}/glance?charset=utf8",
		stores              => ['rbd'],
		default_store       => 'rbd',
		enable_v1_api       => false,
		workers             => 2,
		enable_v2_api       => true,
		bind_host           => $glance_internal_bind_host,
		registry_host       => $glance_registry_advertise_internal_bind_host,
		os_region_name      => $region,
		pipeline            => 'keystone',
		# Enable show_image_direct_url for speedier cow image opertions
		# in ceph. 
		show_image_direct_url => true,
	}

	class { 'glance::notify::rabbitmq':
		default_transport_url      => $rabbitmq_url,
		notification_transport_url => $rabbitmq_url, 
		amqp_durable_queues           => $amqp_durable_queues,
        rabbit_ha_queues        => $rabbit_ha_queues,
		notification_driver        => 'messagingv2',
		rabbit_use_ssl             => false
	}

	class { 'glance::registry':
		bind_host           => $glance_registry_internal_bind_host,
		database_connection =>  "mysql+pymysql://glance_admin:$db_glance_admin_password@${mysql_publish_ip}/glance?charset=utf8",
	}

	class { 'glance::backend::rbd':
		rbd_store_user      => $glance_ceph_client,
		rbd_store_pool      => $glance_backend_pool,
		rbd_store_ceph_conf => '/etc/ceph/ceph.conf',
	}

	# Configure MySQL database for glance
	class { 'glance::db::mysql':
		user          => 'glance_admin',
		password      => $db_glance_admin_password,
		host          => '%',
		allowed_hosts => '%',
		charset       => 'utf8',
	}

	# Configure glance user in keystone
	class { 'glance::keystone::auth':
		password     => $glance_keystone_password,
		email        => $glance_keystone_email,
		public_url   => $glance_public_url,
		admin_url    => $glance_admin_url,
		internal_url => $glance_internal_url,
		region       => $region,
	}

	#
	# Nova (Compute) Configurations 
	#

	# Configure MySQL database for nova, nova_api, and nova_placement
	class { 'nova::db::mysql':
		user          => 'nova_admin',
		password      => $db_nova_admin_password,
		host          => '%',
		allowed_hosts => '%',
		charset       => 'utf8',
	}
	class { 'nova::db::mysql_api':
		user          => 'nova_api_admin',
		password      => $db_nova_api_admin_password,
		host          => '%',
		allowed_hosts => '%',
		charset       => 'utf8',
	}
	class { 'nova::db::mysql_placement':
		user          => 'nova_placement',
		password      => $db_nova_placement_admin_password,
		host          => '%',
		allowed_hosts => '%',
		charset       => 'utf8',
	}

	Class['nova::cell_v2::map_cell0'] -> Nova_cell_v2 <| |>

	class { 'nova::cell_v2::simple_setup':
		transport_url             => $rabbitmq_url,
		database_connection       => "mysql+pymysql://nova_admin:${db_nova_admin_password}@${mysql_publish_ip}/nova?charset=utf8",
		database_connection_cell0 => "mysql+pymysql://nova_admin:${db_nova_admin_password}@${mysql_publish_ip}/nova_cell0?charset=utf8",
	}

	# NOTE(aschultz): workaround for race condition for discover_hosts being run
	# prior to the compute being registered
	exec { 'wait-for-compute-registration':
		path        => ['/bin', '/usr/bin'],
		command     => 'sleep 10',
		refreshonly => true,
		notify      => Class['nova::cell_v2::discover_hosts'],
		subscribe   => Anchor['nova::service::end'],
	}



	# Configure nova user in keystone
	class { 'nova::keystone::auth':
		public_url         => $nova_public_url,
		internal_url       => $nova_internal_url,
		admin_url          => $nova_admin_url,
		region             => $region,
		email              => $nova_keystone_email,
		password           => $nova_keystone_password,
		configure_endpoint => true,
	}
	class { 'nova::keystone::auth_placement':
		public_url         => $nova_placement_public_url,
		internal_url       => $nova_placement_internal_url,
		admin_url          => $nova_placement_admin_url,
		region             => $region,
		email              => $nova_placement_keystone_email,
		password           => $nova_placement_keystone_password,
		configure_endpoint => true,
	}
	class { 'nova::keystone::authtoken':
		password            => $nova_keystone_password,
		user_domain_name    => 'default',
		project_domain_name => 'default',
		auth_url            => $keystone_admin_url,
		auth_uri      		=> $keystone_internal_url,
		memcached_servers   => $memcached_servers,
	}

	class { 'nova':
		database_connection           => "mysql+pymysql://nova_admin:${db_nova_admin_password}@${mysql_publish_ip}/nova?charset=utf8",
		api_database_connection       => "mysql+pymysql://nova_api_admin:${db_nova_api_admin_password}@${mysql_publish_ip}/nova_api?charset=utf8",
		placement_database_connection => "mysql+pymysql://nova_placement:${db_nova_placement_admin_password}@${mysql_publish_ip}/nova_placement?charset=utf8",
		rabbit_use_ssl                => false,
		amqp_sasl_mechanisms          => 'PLAIN',
		glance_api_servers            => $glance_internal_url,
		debug                         => false,
		notification_driver           => 'messagingv2',
		notify_on_state_change     	  => 'vm_and_task_state',
		default_transport_url         => $rabbitmq_url,
		notification_transport_url    => $rabbitmq_url,
		amqp_durable_queues           => $amqp_durable_queues,
		rabbit_ha_queues              => $rabbit_ha_queues,
		cinder_catalog_info           => "volumev2:cinderv2:internalURL",
		# No resource over-subscription
		cpu_allocation_ratio          => '1.0',
        ram_allocation_ratio          => '1.0',
        disk_allocation_ratio         => '1.0',
	}

	class {'nova::availability_zone':
		default_availability_zone => $availability_zone,
		default_schedule_zone     => $availability_zone,
	}

	# Need this otherwise VNC connections from Horizon will only work 1/3 of the time
	class { '::nova::cache':
		enabled          => true,
		backend          => 'oslo_cache.memcache_pool',
		memcache_servers => $memcached_url,
	}

	class {'nova::api':
		api_bind_address                     => $nova_internal_bind_host,
		metadata_listen                      => $nova_internal_bind_host,
		neutron_metadata_proxy_shared_secret => $neutron_metadata_proxy_shared_secret,
		metadata_workers                     => 3,
		sync_db_api                          => true,
		service_name                         => 'httpd',
		enabled                              => true,
	}

	class { 'nova::placement':
		auth_url            => $keystone_admin_url,
		password            => $nova_placement_keystone_password,
		os_region_name      => $region,
		user_domain_name    => 'default',
		project_domain_name => 'default',
	}

	class { 'nova::conductor':
		enabled => true,
	}

	# Apache configurations
	class { 'nova::wsgi::apache_api':
		bind_host => $facts['networking']['ip'],
		ssl       => false, 
		workers   => 2,
	}
	class { 'nova::wsgi::apache_placement':
		bind_host => $facts['networking']['ip'],
		ssl       => false,
		api_port  => '8778',
		path      => '/',
		workers   => 2, 
	}

	class { '::nova::client': }
	class { '::nova::scheduler':
		enabled => true,
	}
	class { '::nova::scheduler::filter':
		# Set RAM weight multiplier to a negative value to pack
		# as many instances onto a host as possible. Equivalent of 
		# "GREEDY" scheduling in Eucalyptus
		ram_weight_multiplier  => '-10.0',
		disk_weight_multiplier => '-10.0',
	}
	class { '::nova::vncproxy':
		enabled           => true,
		host              => $controller_ip,
		vncproxy_protocol => 'https',
	}
	class { '::nova::consoleauth': }
	class { '::nova::cron::archive_deleted_rows': }

	# 
	# Neutron (Network) Configurations
	#

	if $self_service_network {
		$service_plugins = ['router']
		$allow_overlapping_ips = true
		$type_drivers = ['flat', 'vxlan']
		$tenant_network_types = ['vxlan']
		$vni_ranges = '1000:10000'
		$tunnel_types = ['vxlan']
		$local_ip = $facts['networking']['ip']

		$l2_population = true
		$mechanism_drivers = ['linuxbridge', 'l2population']

		class { 'neutron::agents::l3':
			interface_driver  => 'linuxbridge',
			enabled           => true,
			availability_zone => $availability_zone,
		}
	} else {
		$service_plugins = []
		$allow_overlapping_ips = false
		$type_drivers = ['flat']
		$tenant_network_types = []
		$mechanism_drivers = ['linuxbridge']
	$vni_ranges = undef
	$tunnel_types = []
	$local_ip = false
	$l2_population = false
	}

	class { 'nova::network::neutron':
		neutron_password    => $neutron_keystone_password,
		neutron_auth_type   => 'password',
		neutron_url         => $neutron_internal_url,
		neutron_auth_url    => $keystone_admin_url,
		neutron_region_name => $region,
	}

	class { 'nova::compute::neutron': }

	class { 'neutron::keystone::auth':
		region       => $region,
		password     => $neutron_keystone_password,
		email              => $neutron_keystone_email,
		public_url   => $neutron_public_url,
		admin_url    => $neutron_admin_url,
		internal_url => $neutron_internal_url,
	}

	class { 'neutron':
		enabled                    => true,
		bind_host                  => $neutron_internal_bind_host,
		default_transport_url   => $rabbitmq_url,
		dhcp_agents_per_network => '3',
		amqp_durable_queues           => $amqp_durable_queues,
		rabbit_ha_queues        => $rabbit_ha_queues,
		service_plugins         => $service_plugins,
		allow_overlapping_ips   => $allow_overlapping_ips,
		notification_driver     => 'messagingv2',
	}       

	class { 'neutron::keystone::authtoken':
		auth_uri            => $keystone_internal_url,
		auth_url            => $keystone_admin_url,
		password            => $neutron_keystone_password,
		memcached_servers   => $memcached_servers,
		user_domain_name    => 'default',
		project_domain_name => 'default',
	}

	class { 'neutron::server':
		database_connection                 => "mysql+pymysql://neutron_admin:$db_neutron_admin_password@${mysql_publish_ip}/neutron?charset=utf8",
		allow_automatic_l3agent_failover => $high_availability,
		default_availability_zones       => ["$availability_zone"],
		enabled                          => true,
		sync_db                                => true,
		api_workers                            => 2,
		rpc_workers                            => 2,
	}

	class { 'neutron::server::notifications':
		username    => 'nova',
		password    => $nova_keystone_password,
		auth_url    => $keystone_admin_url,
		region_name => $region,
	}

	class { 'neutron::plugins::ml2':
		type_drivers          => $type_drivers,
		tenant_network_types  => $tenant_network_types,
		mechanism_drivers     => $mechanism_drivers,
		flat_networks         => ['provider'],
		vni_ranges            => $vni_ranges,
		enable_security_group => true,
		extension_drivers     => 'port_security,qos',
	}

	class { 'neutron::agents::ml2::linuxbridge':
		physical_interface_mappings => ["provider:$provider_interface",],
		firewall_driver             => "neutron.agent.linux.iptables_firewall.IptablesFirewallDriver",
		tunnel_types                => $tunnel_types,
		local_ip                    => $local_ip,
		l2_population               => $l2_population,
	}
				
	# Shut off the dns server due to:
	#   https://bugs.launchpad.net/neutron/+bug/1501206
	Anchor['neutron::install::end']->
	file { "/etc/neutron/dnsmasq.cnf":
		content => "port=0",
	}->
	class { 'neutron::agents::dhcp':
		interface_driver         => 'linuxbridge',
		dhcp_driver              => 'neutron.agent.linux.dhcp.Dnsmasq',
		enable_isolated_metadata => true,
		enable_metadata_network  => true,
		dnsmasq_config_file      => '/etc/neutron/dnsmasq.cnf',
		availability_zone        => $availability_zone,
	}

	class { 'neutron::agents::metadata':
		 metadata_ip         => $nova_advertise_internal_bind_host,
		 metadata_port       => 8775,
		 shared_secret => $neutron_metadata_proxy_shared_secret,
	}
	
	# Configure MySQL database for neutron
	class { 'neutron::db::mysql':
		user          => 'neutron_admin',
		password      => $db_neutron_admin_password,
		host          => '%',
		allowed_hosts => '%',
		charset       => 'utf8',
	}

	# Set network default quotas
	class { 'neutron::quota':
		quota_security_group => '50',
	}

	# 
	# Cinder (Block) Configurations
	# 
	class { 'cinder':
		database_connection       => "mysql+pymysql://cinder_admin:${db_cinder_admin_password}@${mysql_publish_ip}/cinder?charset=utf8",
		image_conversion_dir      => '/var/lib/cinder/tmp',
		storage_availability_zone => $availability_zone,
		default_availability_zone => $availability_zone,
		default_transport_url     => $rabbitmq_url,
		amqp_durable_queues       => $amqp_durable_queues,
        rabbit_ha_queues    => $rabbit_ha_queues,
		rabbit_use_ssl            => false,
		amqp_sasl_mechanisms      => 'PLAIN',
		debug                     => false,
		enable_v3_api             => true,
		# increase rpc_response_timeout to allow sufficient time 
		# to create volumes from larger images 
		# https://access.redhat.com/solutions/3347651
		rpc_response_timeout      => 1800,
	}

	class { 'cinder::keystone::auth':
		password        => $cinder_keystone_password,
		email           => $cinder_keystone_email,
		public_url      => $cinder_v1_public_url,
		admin_url       => $cinder_v1_admin_url,
		internal_url    => $cinder_v1_internal_url,
		public_url_v2   => $cinder_v2_public_url,
		admin_url_v2    => $cinder_v2_admin_url,
		internal_url_v2 => $cinder_v2_internal_url,
		public_url_v3   => $cinder_v3_public_url,
		admin_url_v3    => $cinder_v3_admin_url,
		internal_url_v3 => $cinder_v3_internal_url,
		region          => $region,
	}

	class { 'cinder::keystone::authtoken':
		password            => $cinder_keystone_password,
		auth_url            => $keystone_admin_url,
		auth_uri            => $keystone_internal_url,
		user_domain_name    => 'default',
		project_domain_name => 'default',
		memcached_servers   => $memcached_servers,
	}
	class { 'cinder::api':
		default_volume_type => 'rbd',
		bind_host           => $cinder_internal_bind_host,
		os_region_name      => $region,
		manage_service      => !$high_availability,
		enabled             => !$high_availability,
		nova_catalog_info   => "compute:Compute Service:internalURL",
	}

	class { 'cinder::scheduler': 
		manage_service => !$high_availability,
		enabled => !$high_availability,
	}
	class { 'cinder::volume':
		manage_service => !$high_availability,
		enabled => !$high_availability,
		volume_clear => 'none',
	}
	class { 'cinder::cron::db_purge': }
	class { 'cinder::glance':
		glance_api_servers => $glance_internal_url,
	}
	include cinder::client

	# define RBD backend
	cinder::backend::rbd { 'rbd':
		rbd_pool           => $cinder_backend_pool,
		rbd_user           => $cinder_ceph_client,
		rbd_secret_uuid    => $rbd_secret_uuid,
		manage_volume_type => true,
	}
	# make sure ceph pool exists before running Cinder API & Volume
	class { 'cinder::backends':
		enabled_backends => ['rbd'],
	}

	# Configure MySQL database for cinder
	class { 'cinder::db::mysql':
		user          => 'cinder_admin',
		password      => $db_cinder_admin_password,
		host          => '%',
		allowed_hosts => '%',
		charset       => 'utf8',
	}

	#
	# Horizon
	#
	class { 'horizon':
		bind_address 				=> $horizon_bind_address,
		secret_key                   => $horizon_secret_key,
		keystone_url                 => "$keystone_internal_url/v3",
		keystone_default_role        => 'admin',
		keystone_default_domain      => 'default',
		keystone_multidomain_support => true,
		api_versions                 => {
			'identity'                  => 3,
			'image'                     => 2,
			'volume'                    => 2,
		},
		allowed_hosts         => '*',
		django_session_engine => 'django.contrib.sessions.backends.cache',
		cache_backend    => 'django.core.cache.backends.memcached.MemcachedCache',	
		cache_server_ip       => $horizon_cache_servers,
		cache_server_port  => '11211',
		neutron_options       => {
			'enable_firewall' => $self_service_network,
			'enable_vpn'      => $self_service_network,
			'enable_router'      => $self_service_network,
			'enable_quotas'      => $self_service_network,
			'enable_distributed_router'      => $self_service_network,
			'enable_ha_router'      => $self_service_network,
			'enable_lb'      => $self_service_network,
			'enable_fip_topology_check'      => $self_service_network,
		},
		vhost_extra_params        => {
			'wsgi_application_group' => "%{GLOBAL}",
			'redirectmatch_dest'     => "https://${ha_hostname}/dashboard",
			'headers'                => 'set X-Forwarded-Proto https'
		},
		# for when behind an ssl proxy
		secure_cookies                 => true,
		enable_secure_proxy_ssl_header => true,
		openstack_endpoint_type        => 'internalURL',
		django_debug                      => false,
		log_level                         => 'DEBUG',
		# Configure Globus Auth
		websso_enabled        => 'True',
		websso_initial_choice => 'credentials',
		websso_choices => [
			['credentials', 'CAC Account'],
			['globus','Globus Auth'],
		],	
		websso_idp_mapping => {
			'credentials'     => ['credentials','password'],
			'globus'          => ['globus','openidc'],
		},
		listen_ssl => false,
		help_url   => 'https://www.cac.cornell.edu/wiki/index.php?title=Red_Cloud',
		# Allow users to retrieve initial Windows admin password
		password_retrieve => true,
		# Allow raw image only because of ceph backend
	    image_backend =>  { 'image_formats' => { 'raw' =>'Raw' } },
	}

	#
	# Swift / Ceph RADOSGW integration
	#
	keystone_user { 'ceph':
		ensure   => present,
		enabled  => true,
		password => $ceph_keystone_password,
		domain   => 'default',
	}
	keystone_user_role { 'ceph@admin':
		roles  => ['admin'],
		ensure => present,
	}
	class {'swift::keystone::auth':
        region                => $region,
        configure_s3_endpoint => false,
        public_url            => $swift_public_url,
        admin_url             => $swift_admin_url,
        internal_url          => $swift_internal_url,
    }

	# 
	# Pacemaker
	#
	if $high_availability {
		class { 'profile::openstack_controller::ha':
			ha_cluster_name    => $ha_cluster_name,
			ha_vip             => $ha_vip,
			ha_node_ips        => $ha_backend_ips,
			ha_node_names      => $ha_backend_names,
			ha_hostname        => $ha_hostname,
			ssl_cert           => $ssl_cert,
			ssl_chain          => $ssl_chain,
			ssl_key            => $ssl_key,
			galera_master      => $galera_master,
			pacemaker_password => $pacemaker_password,
			management_ip      => $management_ip,
			radosgw_hostnames  => split($radosgw_hostnames, ","),
			radosgw_ips        => split($radosgw_ips,","),
		}

		if $galera_master {

			class {'profile::openstack_controller::cinder_pacemaker':}

			# PCS starts the cinder services
			Anchor['cinder::service::begin'] -> Class['profile::openstack_controller::cinder_pacemaker'] -> Anchor['cinder::service::end']

		}


		# Ensure the systemd files exist before we configure PCS
		# Ensure HA ports are listening before services try to use them
		Anchor['keystone::install::end'] -> Class['profile::openstack_controller::ha'] -> Anchor['keystone::config::begin']
		Anchor['nova::install::end'] -> Class['profile::openstack_controller::ha'] -> Anchor['nova::config::begin']
		Anchor['neutron::install::end'] -> Class['profile::openstack_controller::ha'] -> Anchor['neutron::config::begin']
		Anchor['glance::install::end'] -> Class['profile::openstack_controller::ha'] -> Anchor['glance::config::begin']
		Anchor['cinder::install::end'] -> Class['profile::openstack_controller::ha'] -> Anchor['cinder::config::begin']
		#Anchor['panko::install::end'] -> Class['profile::openstack_controller::ha'] -> Anchor['panko::config::begin']
	}

	#
	# Firewall configurations
	#
	if $high_availability {
		firewall_multi { "000 Allow controllers to communicate with each other":
			proto  => 'tcp',
			source => $ha_backend_ips,
			action => 'accept',
		}
	}
	firewall_multi { "100 Keystone public and internal endpoint":
		proto  => 'tcp',
		dport  => 8770,
		action => 'accept',
	}

	firewall { "101 Keystone admin endpoint":
		proto  => 'tcp',
		source => '128.84.8.0/22',
		dport  => 35357,
		action => 'accept',
	}

	firewall_multi { '102 Keystone memcached':
		proto  => 'tcp',
		source => '128.84.8.0/22',
		dport  => 11211,
		action => 'accept',
	}

	firewall_multi { '103 Keystone memcached':
		proto  => 'udp',
		source => '128.84.8.0/22',
		dport  => 11211,
		action => 'accept',
	}
	
	firewall_multi { '104 Glance endpoint':
		proto  => 'tcp',
		dport  => [9191,9292],
		action => 'accept',
	}

	firewall_multi { '105 Cinder':
		proto  => 'tcp',
		dport  => 8776,
		action => 'accept',
	}

	firewall { '106 RabbitMQ':
		proto  => 'tcp',
		source => '128.84.8.0/22',
		dport  => 5672,
		action => 'accept',
	}

	firewall_multi { '107 Nova API and Placement':
		proto  => 'tcp',
		dport  => [8774,8778],
		action => 'accept',
	}
			
	firewall_multi { '108 Neutron':
		proto  => 'tcp',
		dport  => 9696,
		action => 'accept',
	}

	firewall_multi { '109 Horizon':
		proto  => 'tcp',
		dport  => [80,443,6080],
		action => 'accept',
	}

	firewall_multi { '110 Nova API':
		proto  => 'tcp',
		dport  => [8773,8775],
		action => 'accept',
	}

	firewall { '111 VXLAN':
		proto  => 'udp',
		dport  => '4789',
		action => 'accept',
	}
	
	firewall { '112 swift':
		proto  => 'tcp',
		dport  => '8443',
		action => 'accept',
	}
}
