class profile::mariadb (
            $mysql_root_password,
            $bind_address='0.0.0.0',
            $max_connections=1024,
            $high_availability = false,
			$ha_vip,
            $galera_node_ips = undef,
			$galera_node_names = undef,
            $galera_master = false,
            ){

    # Need to do some work on the service management.  Will not restart on reboot
    # Setup so that initial bootstrap works.  Subsequent starts need to be done
    # manually. FIXME

   if $high_availability {

        $wsrep_cluster_address="gcomm://${galera_node_names}"
        $wsrep_node_address=$bind_address
        $wsrep_node_name=$hostname
    
        
        # Probably should replicate wait_for_mysql_socket_to_open
        $init_command = $galera_master ? {
            true  => 'systemctl stop rh-mariadb101-mariadb && scl enable rh-mariadb101 galera_new_cluster && sleep 10',
            false => 'systemctl restart rh-mariadb101-mariadb && sleep 10',
        }

        exec { 'init_galera':
            command => $init_command,
            unless  => 'test -f /var/lib/mysql/galera.cache',
            path    => '/bin:/sbin:/usr/bin:/usr/sbin',
        }

        file { '/etc/opt/rh/rh-mariadb101/my.cnf.d/galera.cnf':
            ensure => absent,
        }

        ensure_packages(['rh-mariadb101-mariadb-server-galera'], {'ensure' => 'present'})
        Package['rh-mariadb101-mariadb-server-galera'] -> Class['::mysql::server']

        File['/etc/opt/rh/rh-mariadb101/my.cnf.d/galera.cnf'] -> Exec['init_galera']
        Package['rh-mariadb101-mariadb-server-galera'] -> File['/etc/opt/rh/rh-mariadb101/my.cnf.d/galera.cnf']

        Class['mysql::server::installdb'] -> Exec['init_galera'] -> Class['mysql::server::service']

        ensure_packages(['xinetd'], {'ensure' => 'present'})

        service {
        xinetd:
            enable => true,
            hasstatus => true,
            ensure => true,
            require => [Package[xinetd],File['/etc/opt/rh/rh-mariadb101/sysconfig/clustercheck'],File['/etc/xinetd.d/galera-monitor']];
        }

        file { '/etc/xinetd.d/galera-monitor':
            ensure => file,
            mode => '0644',
            owner => root,
            group => root,
            notify => [Service[xinetd]],
            require => [ Package['xinetd'], File['/etc/opt/rh/rh-mariadb101/sysconfig/clustercheck'] ],
            source => "puppet:///modules/profile/galera-monitor";
        }

        file { '/etc/opt/rh/rh-mariadb101/sysconfig/clustercheck':
            ensure  => file,
            content => template('profile/clustercheck.erb'),
            owner   => 'root',
            group   => 'root',
            mode    => '0600',
            require => [ Package['rh-mariadb101-mariadb-server-galera'] ],
        }        

		file { '/usr/bin/mysql':
			ensure => 'link',
			target => '/opt/rh/rh-mariadb101/root/bin/mysql',
		}
	
		file { '/usr/bin/mysqld':
			ensure => 'link',
			target => '/opt/rh/rh-mariadb101/root/usr/libexec/mysqld',
		}

        # Some sort of bad interaction between the mariadb puppet class or the default mariadb install and running a galera cluster
        # On first start it expects to be able to use the default root password if there is no .my.cnf
        # The real .my.cnf creation happens sometime later and all is well.
        if !$galera_master {
            exec { 'my.cnf.bootstrap':
                path    => '/bin:/sbin:/usr/bin:/usr/sbin',
                unless  => 'test -f /root/.my.cnf',
                command => "echo -e '[mysql]\nuser=root\nhost=localhost\npassword=${mysql_root_password}\nsocket=/var/lib/mysql/mysql.sock\n\n[client]\nuser=root\nhost=localhost\npassword=${mysql_root_password}\nsocket=/var/lib/mysql/mysql.sock' > /root/.my.cnf",
            }
            Exec['my.cnf.bootstrap'] -> Class['mysql::server']
        }

        class { '::mysql::client':
            package_name => "rh-mariadb101-mariadb",
        }

       class { '::mysql::server':
          config_file                            => "/etc/opt/rh/rh-mariadb101/my.cnf",
          service_manage                         => true,
		  service_enabled                              => true,
		  service_name                                 => 'rh-mariadb101-mariadb',
          package_manage                         => false,
          root_password                          => $mysql_root_password,
          remove_default_accounts                => true,
          override_options                       => {
            'mysqld'                             => {
              'basedir'                          => undef,
              'log-error'                        => "/var/opt/rh/rh-mariadb101/log/mariadb/mariadb.log",
              'pid-file'                         => "/var/run/rh-mariadb101-mariadb/mariadb.pid",
              'bind_address'                     => $bind_address,
              # 'default_storage_engine'         => 'InnoDB',
              'max_connections'                  => $max_connections,
              'open_files_limit'                 => '4294967295',
              'collation_server'                 => 'utf8_general_ci',
              'character_set_server'             => 'utf8',
                'binlog_format'                  => 'ROW',
                'default_storage_engine'         => 'innodb',
                'innodb_autoinc_lock_mode'       => '2',
                'innodb_flush_log_at_trx_commit' => '0',
                'innodb_buffer_pool_size'        => '122M',
                'wsrep_provider'                 => '/opt/rh/rh-mariadb101/root/usr/lib64/galera/libgalera_smm.so',
                'wsrep_sst_method'               => 'rsync',
                'query_cache_size'               => '0',
                'wsrep_cluster_name'             => 'minnusgalera',
                'wsrep_cluster_address'          => $wsrep_cluster_address,
                'wsrep_node_address'             => $wsrep_node_address,
                'wsrep_node_name'                => $wsrep_node_name,
                'wsrep_on'                       => 'ON',
            },
            'mysqld_safe'        => {
              'log-error'        => "/var/opt/rh/rh-mariadb101/log/mariadb/mariadb.log",
            },
          },
        } 
    }
    else {
       class { '::mysql::server':
          config_file       => "/etc/opt/rh/rh-mariadb101/my.cnf",
          restart          => true,
          service_name     => "rh-mariadb101-mariadb",
          package_manage    => false,
          root_password    => $mysql_root_password,
          remove_default_accounts => true,
          override_options => {
            'mysqld' => {
              'bind_address'           => $bind_address,
              'default_storage_engine' => 'InnoDB',
              'max_connections'        => $max_connections,
              #'open_files_limit'       => '4294967295',
              'collation_server'       => 'utf8_general_ci',
              'character_set_server'   => 'utf8'
            },
          },
        } 
    }
	
	# 
	# Firewall Settings
	#
	$cluster_ips = $galera_node_ips.split(',')
	firewall_multi { "100 MySQL":
        proto  => 'tcp',
        source => $cluster_ips,
        dport  => 3306,
        action => 'accept',
    }
	if $high_availability {
		firewall {"101 MySQL HA VIP":
			proto  => 'tcp',
			source => $ha_vip,
			dport => 3306,
			action => 'accept',
		}
	}
	firewall_multi { "101 Galera Cluster replication TCP":
		proto  => 'tcp',
        source => $cluster_ips,
        dport  => 4567,
        action => 'accept',
	}
	firewall_multi { "102 Galera Cluster replication UDP":
        proto  => 'udp',
        source => $cluster_ips,
        dport  => 4567,
        action => 'accept',
    }
    firewall_multi { "103 Incremental State Transfer":
        proto  => 'tcp',
        source => $cluster_ips,
        dport  => 4568,
        action => 'accept',
    }
    firewall_multi { "104 State Snapshot Transfer":
        proto  => 'tcp',
        source => $cluster_ips,
        dport  => 4444,
        action => 'accept',
	}
	firewall_multi { '105 Galera Monitor':
		proto => 'tcp',
		source => $cluster_ips,
        dport  => 9200,
        action => 'accept',
    }
}
