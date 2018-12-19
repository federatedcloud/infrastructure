class profile::openstack_controller::ha (
	$ha_cluster_name,
	$ha_node_names,
	$ha_node_ips,
	$ha_vip,
	$ha_hostname,
	$ssl_cert,
	$ssl_chain,
	$ssl_key,
	$galera_master,
	$pacemaker_password,
	$management_ip,
	$radosgw_hostnames,
	$radosgw_ips,
) {

	file_line {
		'rsyslog1':
			path  => '/etc/rsyslog.conf',
			line  => '$ModLoad imudp',
			ensure => 'present';
		'rsyslog2':
			path  => '/etc/rsyslog.conf',
			line  => '$UDPServerRun 514',
			ensure => 'present';
	}

	file { '/etc/rsyslog.d/haproxy.conf':
		ensure => file,
		mode => '0644',
		owner => 'root',
		group => 'root',
		notify => [Service[rsyslog]],
		source => "puppet:///modules/profile/openstack_controller/haproxy.conf";
	}

	File['/etc/rsyslog.d/haproxy.conf'] -> File_line['rsyslog1']
	File_line['rsyslog1'] -> Service['rsyslog']
	File_line['rsyslog2'] -> Service['rsyslog']

	service { 'rsyslog':
		enable => true,
		hasstatus => true,
		ensure => true,
	}

	sysctl::value { 'net.ipv4.tcp_keepalive_intvl':
		value => '1',
	}

	sysctl::value { 'net.ipv4.tcp_keepalive_probes':
		value => '5',
			}

	sysctl::value { 'net.ipv4.tcp_keepalive_time':
		value => '5',
	}

	include pace_properties

	Class['pacemaker::new'] -> Class['pace_properties']
	Class['pacemaker::new'] -> Pacemaker_resource<||>
	Pacemaker_resource<| tag == 'ha_stage_1' |> -> Pacemaker_order<| tag == 'ha_stage_1' |>
	Pacemaker_resource<| tag == 'ha_stage_1' |> -> Pacemaker_colocation<| tag == 'ha_stage_1' |>

	class { '::pacemaker::new' :
		cluster_nodes    => $ha_node_names,
		cluster_name     => $ha_cluster_name,
		cluster_password => $pacemaker_password,
		# Only one node needs to do this apparently.  Would be nice if it was documentaed somewhere
		cluster_setup => any2bool($galera_master),
		firewall_corosync_manage => true,
		firewall_pcsd_manage     => true,
	}
		
	pacemaker_resource { "lb-haproxy":
		ensure => 'present',
		primitive_class => 'systemd',
		primitive_type => 'haproxy',
		complex_type => "clone",
		tag    => ['ha_stage_1'],
	}

	pacemaker::new::resource::ip { "vip-${ha_vip}":
		ip_address => $ha_vip,
		cidr_netmask => "24",
		operations => {"monitor" => { "interval" => "30s"}},
		tag    => ['ha_stage_1'],
	}

	pacemaker_order { "lb-order-${ha_vip}" :
		first         => "ip-${ha_vip}",
		first_action  => 'start',
		second        => 'lb-haproxy-clone',
		kind          => 'optional',
		tag    => ['ha_stage_1'],
	}

	pacemaker_colocation { "lb-colo-${ha_vip}" :
		first  => 'lb-haproxy-clone',
		second => "ip-${ha_vip}",
		tag    => ['ha_stage_1'],
	}

	##
	# HA Proxy
	##

	# Stats
	haproxy::listen { 'stats':
		ipaddress => $management_ip,
		ports     => '9000',
		options   => {
			'stats'  => ['enable', 'uri /', "auth admin:${haproxy_stats_password}"],
			'mode' => 'http',
		}
	}

	file { "/etc/pki/tls/certs/${ha_hostname}_cert.pem":
		owner   => 'root',
		group   => 'root',
		mode    => '0444',
		content => $ssl_cert,
	}

	Haproxy::Install['haproxy']->
		file { "/etc/pki/tls/private/${ha_hostname}_key.pem":
			owner   => 'root',
			group   => 'root',
			mode    => '0444',
			content => "$ssl_cert\n$ssl_key\n$ssl_chain\n",
		}-> Haproxy::Config['haproxy']

	$stats_ssl_bind = { "$ha_vip:9000" => ['ssl', 'crt', "/etc/pki/tls/private/${ha_hostname}_key.pem"] }

	haproxy::listen { 'stats_cluster':
		bind      => $stats_ssl_bind,
		options   => {
			'mode'    => 'http',
			'balance' => 'source'
		}
	}

	haproxy::balancermember { 'stats_proxy':
		listening_service => 'stats_cluster',
		ports             => '9000',
		server_names      => $ha_node_names,
		ipaddresses       => $ha_node_ips,
	}

	sysctl::value { 'net.ipv4.ip_nonlocal_bind': value => '1' }-> 
		class { 'haproxy':
			global_options => {
				'chroot' =>  '/var/lib/haproxy',
				'daemon' => '',
				'group' =>  'haproxy',
				'log' =>  "$management_ip local0",
				'maxconn' =>  '4000',
				'pidfile' =>  '/var/run/haproxy.pid',
				'stats' =>  'socket /var/lib/haproxy/stats',
				'user' =>  'haproxy',
				'tune.ssl.default-dh-param' => '2048',
				'ssl-default-bind-ciphers' => 'ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA:ECDHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA256:DHE-RSA-AES256-SHA:ECDHE-ECDSA-DES-CBC3-SHA:ECDHE-RSA-DES-CBC3-SHA:EDH-RSA-DES-CBC3-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:DES-CBC3-SHA:!DSS',
				'ssl-default-bind-options' => 'no-sslv3 no-tls-tickets',
				'ssl-default-server-ciphers' => 'ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA:ECDHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA256:DHE-RSA-AES256-SHA:ECDHE-ECDSA-DES-CBC3-SHA:ECDHE-RSA-DES-CBC3-SHA:EDH-RSA-DES-CBC3-SHA:AES128-GCM-SHA256:AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:DES-CBC3-SHA:!DSS',
				'ssl-default-server-options' => 'no-sslv3 no-tls-tickets',
			},
		defaults_options => {
			'log'     => 'global',
			'option'  => 'redispatch',
			'retries' => '3',
			'timeout' => [
				'http-request 10s',
				'queue 1m',
				'connect 10s',
				'client 1m',
				'server 1m',
				'check 10s',
			],
			'maxconn' => '8000',
		},
	}

	###
	# Horizon
	###
	$horizon_default_bind = { "$ha_vip:80" => [] }
	$horizon_ssl_bind = { "$ha_vip:443" => ['ssl', 'crt', "/etc/pki/tls/private/${ha_hostname}_key.pem"] }

	haproxy::listen { 'dashboard_cluster_http':
		bind      => merge( $horizon_default_bind, $horizon_ssl_bind ),
		options   => {
			# The dashboard does some redirects, so we need to listen on 80, but just redirect to https ourselves
			# But only do this on the external interface
			'option'        => ['forwardfor', 'httpchk', 'httpclose'],
			'mode'          => 'http',
			'cookie'        => 'SERVERID insert indirect nocache',
			'capture'       => 'cookie vgnvisitor= len 32',
			'balance'       => 'source',
			'rspidel'       => '^Set-cookie:\ IP=',
			'redirect'      => 'scheme https code 301 if !{ ssl_fc }',
			'http-response' => 'set-header Strict-Transport-Security max-age=15768000',
			'http-request'  => ['set-header X-Forwarded-Proto https'],
		}
	}
      
	haproxy::balancermember { 'dashboard_http':
    	listening_service => 'dashboard_cluster_http',
        ports             => '80',
        server_names      => $ha_node_names,
		ipaddresses       => $ha_node_ips,
		options           => 'check inter 2000 rise 2 fall 5',
		define_cookies    => true
	}

	###
	# VNC
	###
   	$vnc_ssl_bind = { "$ha_vip:6080" => ['ssl', 'crt', "/etc/pki/tls/private/${ha_hostname}_key.pem"] }

    haproxy::listen { 'vnc_cluster':
		bind      => $vnc_ssl_bind,
		options   => {
        	# Try a tcpchk instead to see if that fixes all of the disconnect messages
            # Also: https://review.openstack.org/#/c/232986/ implies you need the tunnel param
            'option'  => ['forwardfor', 'tcpka', 'tcp-check', 'httpclose'],
            'timeout' => [ 'tunnel 1h' ],
            #'option'  => ['forwardfor', 'httpchk GET /', 'httpclose'],
            'mode'    => 'http',
            'balance' => 'source'
		}
	}
      
    haproxy::balancermember { 'vnc':
    	listening_service => 'vnc_cluster',
    	ports             => '6080',
    	server_names      => $ha_node_names,
    	ipaddresses       => $ha_node_ips,
		# Turn off check for now. Spams log with "Connection reset by peer"
		options           => 'check inter 2000 rise 2 fall 5',
	}
 
	##
	# keystone
	##
	$keystone_admin_bind = { "$ha_vip:35357" => ['ssl', 'crt', "/etc/pki/tls/private/${ha_hostname}_key.pem"] }

	haproxy::listen { 'keystone_admin_cluster':
    	bind      => $keystone_admin_bind,
		options   => {
        	'option'     => ['tcpka', 'httpchk', 'tcplog'],
            'balance'    => 'source',
          }
	}      
      
    $keystone_ssl_bind = { "$ha_vip:8770" => ['ssl', 'crt', "/etc/pki/tls/private/${ha_hostname}_key.pem"] }

    haproxy::listen { 'keystone_public_internal_cluster':
    	bind              => $keystone_ssl_bind,
       	options        => {
        	'option'   => ['tcpka', 'httpchk', 'tcplog'],
        	'balance'  => 'source',
			'mode'     => 'http',
			'cookie'   => 'SERVERID insert indirect nocache',
            'capture'  => 'cookie vgnvisitor= len 32',
			'rspidel'  => '^Set-cookie:\ IP=',
            'redirect' => 'scheme https code 301 if !{ ssl_fc }',
			'http-response' => 'set-header Strict-Transport-Security max-age=15768000',
			'http-request'  => ['set-header X-Forwarded-Proto https'],
       	}
	}
      
	haproxy::balancermember { 'keystone_admin':
    	listening_service => 'keystone_admin_cluster',
    	ports             => '35357',
    	server_names      => $ha_node_names,
		ipaddresses       => $ha_node_ips,
		options           => "check inter 2000 rise 2 fall 5",
	}
      
	haproxy::balancermember { 'keystone_public_internal':
    	listening_service => 'keystone_public_internal_cluster',
    	ports             => '8770',
    	server_names      => $ha_node_names,
   		ipaddresses       => $ha_node_ips,
   		options           => "check inter 2000 rise 2 fall 5",
	}


	##
	# Glance
	##
	$glance_registry_ssl_bind = { "$ha_vip:9191" => ['ssl', 'crt', "/etc/pki/tls/private/${ha_hostname}_key.pem"] }

    haproxy::listen { 'glance_registry_cluster':
		bind      => $glance_registry_ssl_bind,
		options   => {
			'option'  => ['tcpka', 'tcplog'],
			'balance' => 'source',
       	}
	}
      
	haproxy::balancermember { 'glance_registry':
		listening_service => 'glance_registry_cluster',
		ports             => '9191',
		server_names      => $ha_node_names,
 		ipaddresses       => $ha_node_ips,
		options           => 'check inter 2000 rise 2 fall 5',
	}
      
	$glance_api_ssl_bind = { "$ha_vip:9292" => ['ssl', 'crt', "/etc/pki/tls/private/${ha_hostname}_key.pem"] }

	haproxy::listen { 'glance_api_cluster':
		bind      => $glance_api_ssl_bind,
		options   => {
			'option'  => ['tcpka', 'httpchk', 'tcplog'],
			'balance' => 'source',
		}
	}
      
	haproxy::balancermember { 'glance_api':
		listening_service => 'glance_api_cluster',
		ports             => '9292',
		server_names      => $ha_node_names,
		ipaddresses       => $ha_node_ips,
          options           => 'check inter 2000 rise 2 fall 5',
	}

	##
    # Nova
	##
	$nova_default_bind = { "$ha_vip:8774" => [] }
    $nova_ssl_bind = { "$ha_vip:8774" => ['ssl', 'crt', "/etc/pki/tls/private/${ha_hostname}_key.pem"] }

    haproxy::listen { 'nova_cluster':
		bind        => $nova_default_bind,
		options     => {
			'option'   => ['tcpka', 'httpchk', 'tcplog'],
			'balance'  => 'source',
			'mode'     => 'http',
		}
	}
      
	haproxy::balancermember { 'nova':
		listening_service => 'nova_cluster',
		ports             => '8774',
		server_names      => $ha_node_names,
		ipaddresses       => $ha_node_ips,
		options           => 'check inter 2000 rise 2 fall 5',
	}
     
	$nova_metadata_default_bind = { "$ha_vip:8775" => [] }   

    haproxy::listen { 'nova_metadata_cluster':
		bind           => $nova_metadata_default_bind,
		options        => {
			'option'      => ['tcpka', 'httpchk', 'tcplog'],
			'balance'     => 'source',
			'mode'        => 'http',
			'acl'         => 'network_allowed src 128.84.8.0/22 192.168.0.0/16 10.0.0.0/8 172.16.0.0/16',
			'tcp-request' => 'connection reject if !network_allowed',
		}
	}
      
	haproxy::balancermember { 'nova_metadata':
		listening_service => 'nova_metadata_cluster',
		ports             => '8775',
		server_names      => $ha_node_names,
		ipaddresses       => $ha_node_ips,
		options           => 'check inter 2000 rise 2 fall 5',
	}

    $nova_placement_ssl_bind = { "$ha_vip:8778" => ['ssl', 'crt', "/etc/pki/tls/private/${ha_hostname}_key.pem"] }

	haproxy::listen { 'nova_placement_cluster':
		bind      => $nova_placement_ssl_bind,
		options   => {
         	# httpchk fails since the placement api sends a 401.  Not sure if there is a way around that
            #'option'  => ['tcpka', 'httpchk', 'tcplog'],
            'option'  => ['tcpka', 'tcplog'],
            'balance' => 'source',
			'redirect' =>'scheme https code 301 if !{ ssl_fc }',

        }
	}
      
    haproxy::balancermember { 'nova_placement':
    	listening_service => 'nova_placement_cluster',
		ports             => '8778',
		server_names      => $ha_node_names,
		ipaddresses       => $ha_node_ips,
		options           => 'check inter 2000 rise 2 fall 5',
	}


	##
	# Cinder
	##
	$cinder_ssl_bind = { "$ha_vip:8776" => ['ssl', 'crt', "/etc/pki/tls/private/${ha_hostname}_key.pem"] }

	haproxy::listen { 'cinder_api_cluster':
		bind      => $cinder_ssl_bind,
		options   => {
        	'option'  => ['tcpka', 'httpchk', 'tcplog'],
            'balance' => 'source',
			'redirect' =>'scheme https code 301 if !{ ssl_fc }',

          }
	}
      
    haproxy::balancermember { 'cinder_api':
    	listening_service => 'cinder_api_cluster',
		ports             => '8776',
       	server_names      => $ha_node_names,
        ipaddresses       => $ha_node_ips,
		options           => 'check inter 2000 rise 2 fall 5',
	}

	###
    # Neutron
	###

    $neutron_ssl_bind = { "$ha_vip:9696" => ['ssl', 'crt', "/etc/pki/tls/private/${ha_hostname}_key.pem"] }

	haproxy::listen { 'neutron_api_cluster':
		bind      => $neutron_ssl_bind,
		options   => {
			'option'  => ['tcpka', 'httpchk', 'tcplog'],
			'balance' => 'source',
            'redirect' =>'scheme https code 301 if !{ ssl_fc }',
		}
	}
      
	haproxy::balancermember { 'neutron_api_primary':
		listening_service => 'neutron_api_cluster',
		ports             => '9696',
		server_names      => $ha_node_names,
		ipaddresses       => $ha_node_ips,
		options           => 'check inter 2000 rise 2 fall 5',
	}

	##
	# Swift/Ceph RADOSGW
	##
	$swift_ssl_bind = { "$ha_vip:8443" => ['ssl', 'crt', "/etc/pki/tls/private/${ha_hostname}_key.pem"] }

    haproxy::listen { 'radosgw_cluster':
        bind          => $swift_ssl_bind,
        options       => {
            'balance' => 'source',
			'mode'             => 'http',
       }
    }

    haproxy::balancermember { 'radosgw':
        listening_service => 'radosgw_cluster',
        ports             => '80',
        server_names      => $radosgw_hostnames,
        ipaddresses       => $radosgw_ips,
        options           => 'check inter 2000 rise 2 fall 5',
    }


	##
    # mysql
    ##

    haproxy::listen { 'galera_cluster':
		bind              =>  {
			"${ha_vip}:3306" => [],
		},
		options   => {
			# I think this is a documentation error when using clustercheck
       		#'option'     => ['mysql-check'],
        	'option'     => ['httpchk'],
        	'balance'    => 'source',
        }
	}      
      
    # A/P
	haproxy::balancermember { 'galera_primary':
		listening_service => 'galera_cluster',
        ports             => '3306',
		server_names      => $ha_node_names[0],
		ipaddresses       => $ha_node_ips[0],
        options           => "check port 9200 inter 2000 rise 2 fall 5",
	}

    haproxy::balancermember { 'galera_backup':
		listening_service => 'galera_cluster',
		ports             => '3306',
		server_names      => delete_at($ha_node_names, 0),
        ipaddresses       => delete_at($ha_node_ips,0),
        options           => "backup check port 9200 inter 2000 rise 2 fall 5",
    }

	###
	# Firewall
	###
	firewall { '200 Corosync IGMP ':
		proto  => 'igmp',
        action => 'accept',
    }
	
	firewall { '201 Corosync Multicast':
		dst_type => 'MULTICAST',
		action   => 'accept',
	}

	firewall_multi { '202 Corosync':
		proto  => 'tcp',
        dport  => [5404,5405],
        action => 'accept',
    }

}

class pace_properties {
        pacemaker_property { 'stonith-enabled' :
          ensure => 'present',
          value  => false,
        }
        pacemaker_property { 'no-quorum-policy' :
          ensure => 'present',
          value  => 'ignore',
        }
        pacemaker_property { 'pe-warn-series-max' :
          ensure => 'present',
          value  => '1000',
        }
        pacemaker_property { 'pe-input-series-max' :
          ensure => 'present',
          value  => '1000',
        }
        pacemaker_property { 'pe-error-series-max' :
          ensure => 'present',
          value  => '1000',
        }
        pacemaker_property { 'cluster-recheck-interval' :
          ensure => 'present',
          value  => '5min',
        }
}

