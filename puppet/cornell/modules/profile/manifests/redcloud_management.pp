class profile::redcloud_management (
	$admin_password,
	$auth_url,
	$ldap_url,
    $ldap_bind_dn,
    $ldap_bind_password,
   	$mapping_name,
) {
	class {'redcloud_user_account':
		admin_password           => $admin_password,
		auth_url                 => $auth_url,
		ldap_url                 => $ldap_url,
        ldap_bind_dn       => $ldap_bind_dn,
        ldap_bind_password => $ldap_bind_password,
        mapping_name      => $mapping_name,
	}
}
