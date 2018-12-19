class profile::openstack_compute (
	$management_interface = '',
	$enabled = false,
	$controller_ip = '127.0.0.1',
	$self_service_network = false,
	$high_availability = false,
	$ha_host_ipaddresses = undef,
	$region = 'RegionOne',
	$availability_zone = 'nova',
	$provider_interface = '',
	$rabbitmq_user = '',
	$rabbitmq_password = 'changeme',
	$nova_keystone_password = 'changeme',
	$nova_placement_keystone_password = 'changeme',
	$cinder_ceph_client = 'cinder',
    $cinder_ceph_client_key = '',
    $rbd_secret_uuid = '',
	$neutron_keystone_password = 'changeme',
	$neutron_metadata_proxy_shared_secret = 'changeme',
	$libvirt_cpu_model = undef,
) {
	if !$enabled {
        notify { "profile::openstack_compute class applied but not enabled":}
    }
    else {
		$management_ip = $facts['networking']['interfaces'][$management_interface]['ip']
		$overlay_ip = $management_ip
		$keystone_ip = $controller_ip
		$glance_ip = $controller_ip
		$mysql_ip = $controller_ip
		$nova_ip = $controller_ip
		$neutron_ip = $controller_ip

		if $high_availability {
			$amqp_durable_queues = false 
        	$rabbit_ha_queues = true
    
        	sysctl::value { 'net.ipv4.tcp_keepalive_intvl':
         		value => '1',
        	}
    
        	sysctl::value { 'net.ipv4.tcp_keepalive_probes':
          		value => '5',
        	}
    
        	sysctl::value { 'net.ipv4.tcp_keepalive_time':
          		value => '5',
        	}    

			$ha_backend_ips  = split($ha_host_ipaddresses, ",")
			$ha_rabbit_list = $ha_backend_ips.map |$node| {"${rabbitmq_user}:${rabbitmq_password}@$node:5672" }.join(",")
			$rabbitmq_url = "rabbit://${ha_rabbit_list}"
			$memcached_url = $ha_backend_ips.map |$node| {"${node}:11211"}.join(",")
    	}
		else {
        	$amqp_durable_queues = false
        	$rabbit_ha_queues = false
			
			$rabbitmq_url = os_transport_url({
            	'transport' => 'rabbit',
                'host'      => $controller_ip,
                'port'      => '5672',
                'username'  => $rabbitmq_user,
                'password'  => $rabbitmq_password,
				})
			$memcached_url = "${controller_ip}:11211"
    	}

		$keystone_public_url = "https://${keystone_ip}:8770/v3"
		$keystone_admin_url = "https://${keystone_ip}:35357/v3"
		$keystone_internal_url = "https://${keystone_ip}:8770/v3"
		
		$glance_public_url = "https://${glance_ip}:9292"
		$glance_admin_url = "https://${glance_ip}:9292"
		$glance_internal_url = "https://${glance_ip}:9292"

		$nova_placement_public_url = "https://${nova_ip}:8778"
		$nova_placement_admin_url = "https://${nova_ip}:8778"
		$nova_placement_internal_url = "https://${nova_ip}:8778"
	
		$neutron_public_url = "https://${neutron_ip}:9696"
		$neutron_admin_url = "https://${neutron_ip}:9696"
		$neutron_internal_url = "https://${neutron_ip}:9696"
	
		# remove NetworkManager
        #
		service { 'NetworkManager':
        	ensure => 'stopped',
	    }
        package { 'NetworkManager':
                ensure => 'purged',
        }

		#
    	# Activate provider interface
    	#
    	include network
    	network_config { "$provider_interface":
			ensure       => 'present',
        	onboot => true,
    	}

		#
		# Configure tuned
		#
		class { 'tuned':
			profile => 'virtual-host',
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
	
		
		# Nova
		#
	
		class { 'nova':
			default_transport_url  => $rabbitmq_url,
			amqp_durable_queues    => $amqp_durable_queues,
			rabbit_ha_queues       => $rabbit_ha_queues,
			glance_api_servers     => $glance_internal_url,
			os_region_name         => $region,
			cinder_catalog_info    => "volumev3:cinderv3:internalURL",
			notify_on_state_change => "vm_and_task_state",
			notification_driver    => "messagingv2",
			# Allow time for creating volumes from larger images
			# https://access.redhat.com/solutions/3347651
			block_device_allocate_retries          => 1800,
			block_device_allocate_retries_interval => 3,
		}

		class { 'nova::keystone::authtoken':
			auth_uri            => $keystone_public_url,
			auth_url            => $keystone_admin_url,
			password            => $nova_keystone_password,
			memcached_servers   => $memcached_url,
			user_domain_name    => 'default',
			project_domain_name => 'default',
		}

		# nova::compute "includes" availability_zone,
		Nova_config <| title == 'DEFAULT/default_availability_zone' |> { value => "${availability_zone}" }
    Nova_config <| title == 'DEFAULT/default_schedule_zone' |> { value => "${availability_zone}" }

		class { 'nova::compute':
			enabled                       => true,
			vncproxy_host                 => 'redcloud.cac.cornell.edu',
			vncproxy_protocol             => 'https',
			vncserver_proxyclient_address => $management_ip,
			instance_usage_audit          => true,
			instance_usage_audit_period   => 'hour',
		}

		class { 'nova::placement':
			auth_url            => $keystone_admin_url,
			password            => $nova_placement_keystone_password,
			os_region_name      => $region,
			user_domain_name    => 'default',
			project_domain_name => 'default',
		}

		if $libvirt_cpu_model != undef {
			class { 'nova::compute::libvirt':
				libvirt_virt_type => 'kvm',
				vncserver_listen  => '0.0.0.0',
				libvirt_cpu_mode  => 'custom',
				libvirt_cpu_model => $libvirt_cpu_model,
			}
		} 
		else
		{
            class { 'nova::compute::libvirt':
                libvirt_virt_type => 'kvm',
                vncserver_listen  => '0.0.0.0',
            }
		}
		
		class { '::nova::migration::libvirt':
        	listen_address => $management_ip,
    	}
		
		#
		# Neutron
		#

		if $self_service_network {
        	$tunnel_types = ['vxlan']
        	$local_ip = $overlay_ip
            $l2_population = true
    	} else {
        	$tunnel_types = []
        	$local_ip = false
        	$l2_population = false
    	}

		class { 'nova::network::neutron':
			neutron_password    => $neutron_keystone_password,
			neutron_url         => $neutron_internal_url,
			neutron_auth_url    => $keystone_admin_url,
			neutron_region_name => $region,
		}	

		class { 'neutron':
			enabled               => true,
			default_transport_url => $rabbitmq_url,
			amqp_durable_queues => $amqp_durable_queues,
			rabbit_ha_queues => $rabbit_ha_queues,
		}

		class { 'neutron::agents::ml2::linuxbridge':
			enabled                     => true,
			physical_interface_mappings => ["provider:$provider_interface",],
			firewall_driver             => "neutron.agent.linux.iptables_firewall.IptablesFirewallDriver",
			tunnel_types                => $tunnel_types,
			local_ip                    => $local_ip,
			l2_population               => $l2_population,
		}

		# Install l3 agent as a workaround?
        # https://ask.openstack.org/en/question/111750/neutron-error-agentnotfoundbytypehost-agent-with-agent_typel3-agent-and-hostcompute1examplecom-could-not-be-found-caused-by-l2population
        class { 'neutron::agents::l3':
        	interface_driver  => 'linuxbridge',
            enabled           => true,
            availability_zone => $availability_zone,
        }
		class { 'neutron::agents::metadata':
                 metadata_ip         => $controller_ip,
                 metadata_port       => 8775,
                 shared_secret => $neutron_metadata_proxy_shared_secret,
        }


		class { 'neutron::keystone::authtoken':
			auth_uri            => $keystone_public_url,
			auth_url            => $keystone_admin_url,
			password            => $neutron_keystone_password,
			memcached_servers   => $memcached_url,
			user_domain_name    => 'default',
			project_domain_name => 'default',
		}

		# 
    	# Configure Ceph
    	#
    	file { '/etc/ceph/ceph.conf':
        	ensure => file,
        	owner  => 'root',
        	group  => 'root',
        	mode   => '0444',
        	source => 'puppet:///modules/cac_ceph_client/ceph.conf',
    	}
		file { '/etc/ceph/ceph.client.cinder.keyring':
                ensure => file,
                owner  => 'nova',
                group  => 'root',
                mode   => '0400',
                content => epp( 'cac_ceph_client/client.keyring.epp',
                                        { client_name => $cinder_ceph_client,
                                          client_key => $cinder_ceph_client_key, } ),
		}
		class { 'nova::compute::rbd':
			libvirt_rbd_secret_uuid => $rbd_secret_uuid,
			libvirt_rbd_secret_key  => $cinder_ceph_client_key,
			libvirt_rbd_user        => 'cinder',
			libvirt_images_rbd_pool => "vms",
		}

		#
    	# Firewall configurations
    	#
    	firewall { '100 VNC Servers for instances':
        	proto  => 'tcp',
			source       => '128.84.8.0/22',
        	dport  => ["5900-5999",],
        	action => 'accept',
    	}
		firewall { '101 VXLAN':
			proto  => 'udp',
			dport  => '4789',
			action => 'accept',
		}
		firewall { '102 libvirt live migration':
			proto  => 'tcp',
			source => '128.84.8.0/22',
			dport  => ['16509',"49152-49261",],
			action => 'accept',
		}
	}
}
