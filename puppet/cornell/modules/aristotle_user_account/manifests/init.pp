class aristotle_user_account (
	$admin_password,
	$auth_url,
	$aristotle_mapping_name,
	$aristotle_domain,
) {
	#
	# Python, pip, and virtualenv
	#
	class {'python':
		pip        => present,
		dev        => present,
		virtualenv => present,
	}
	python::virtualenv {'/root/bin/aristotle':
		ensure => present,
		owner  => 'root',
		group  => 'root',
		cwd    => '/root/bin/aristotle',	
	}
	# 
	# Install required python packages in virtualenv
	#
	# openstacksdk
	python::pip {'openstacksdk':
		ensure     => '0.16.0',
		virtualenv => '/root/bin/aristotle',
	}

	# python-ldap
	package { ['gcc','openldap-devel']:
		ensure => present,
	}
	python::pip {'python-ldap':
        ensure     => present,
        virtualenv => '/root/bin/aristotle',
    }
	
	file { ['/root/.config','/root/.config/openstack','/root/bin']:
		ensure => directory,
		owner  => 'root',
		group  => 'root',
		mode   => '0755',
	}
	file { '/root/.config/openstack/clouds.yaml':
		ensure             => file,
		owner              => 'root',
		group              => 'root',
		mode               => '0644',
		content            => epp( 'aristotle_user_account/clouds.yaml.epp',
				{ admin_password => $admin_password,
				  auth_url       => $auth_url, } )
	}

	# Add generate_mapping.py
	file {'/root/bin/aristotle/generate_mapping_from_portal.py':
       	ensure                               => file,
       	owner                                => 'root',
       	group                                => 'root',
       	mode                                 => '0755',
       	content                              => epp( 'aristotle_user_account/generate_mapping_from_portal.py.epp',
   	                { aristotle_mapping_name => $aristotle_mapping_name,
					  aristotle_domain => $aristotle_domain  } ),
	}

	# 
	# Add Cron jobs
	#
	include cron
	cron::job { 'generate_mapping_from_portal':
        minute      => '*/5',
        user        => 'root',
        command     => '. /root/openrc; source /root/bin/aristotle/bin/activate; cd /root/bin/aristotle; python /root/bin/aristotle/generate_mapping_from_portal.py',
        environment => [ 'MAILTO=""', 'PATH="/usr/bin:/bin"', ],
        description => 'Generate mapping per globus sub',
    }
}
