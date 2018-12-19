# A description of what this class does
#
# @summary A short summary of the purpose of this class
#
# @example
#   include redcloud_user_account
class redcloud_user_account (
	$admin_password,
	$auth_url,
	$ldap_url,
	$ldap_bind_dn,
	$ldap_bind_password,
	$mapping_name,
) {
	#
	# Python, pip, and virtualenv
	#
	class {'python':
		pip        => present,
		dev        => present,
		virtualenv => present,
	}
	python::virtualenv {'/root/bin/redcloud':
		ensure => present,
		owner  => 'root',
		group  => 'root',
		cwd    => '/root/bin/redcloud',	
	}
	# 
	# Install required python packages in virtualenv
	#
	# openstacksdk
	python::pip {'openstacksdk':
		ensure     => '0.16.0',
		virtualenv => '/root/bin/redcloud',
	}

	# python-ldap
	package { ['gcc','openldap-devel']:
		ensure => present,
	}
	python::pip {'python-ldap':
        ensure     => present,
        virtualenv => '/root/bin/redcloud',
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
		content            => epp( 'redcloud_user_account/clouds.yaml.epp',
				{ admin_password => $admin_password,
				  auth_url       => $auth_url, } )
	}

	# Add add_new_projects.py
	file {'/root/bin/redcloud/add_new_projects.py':
		ensure => file,
		owner  => 'root',
		group  => 'root',	
		mode   => '0755',
		source => 'puppet:///modules/redcloud_user_account/add_new_projects.py',

	}

	# Add generate_mapping.py
	file {'/root/bin/redcloud/mapping_template.json':
		ensure => file,
		owner  => 'root',
		group  => 'root',
		mode   => '0644',
		source => 'puppet:///modules/redcloud_user_account/mapping_template.json',
	}
	file {'/root/bin/redcloud/generate_mapping.py':
		ensure                  => file,
		owner                   => 'root',
		group                   => 'root',
		mode                    => '0755',
		content                 => epp( 'redcloud_user_account/generate_mapping.py.epp',
					{ ldap_url           => $ldap_url,
					  ldap_bind_dn       => $ldap_bind_dn,
					  ldap_bind_password => $ldap_bind_password,
					  mapping_name       => $mapping_name, } ),
	}

	# 
	# Add Cron jobs
	#
	include cron
	cron::job { 'add_new_projects':
		minute      => '*/5',
		user        => 'root',
		command     => '. /root/openrc; source /root/bin/redcloud/bin/activate; cd /root/bin/redcloud; python /root/bin/redcloud/add_new_projects.py',
		environment => [ 'MAILTO=""', 'PATH="/usr/bin:/bin"', ],
		description => 'Create a new project for a new group',
	}
	cron::job { 'generate_mapping':
        minute      => '*/5',
        user        => 'root',
        command     => '. /root/openrc; source /root/bin/redcloud/bin/activate; cd /root/bin/redcloud; python /root/bin/redcloud/generate_mapping.py',
        environment => [ 'MAILTO=""', 'PATH="/usr/bin:/bin"', ],
        description => 'Generate mapping per globus sub in Active Directory for globus domain',
    }
}
