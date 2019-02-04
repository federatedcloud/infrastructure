class profile::aristotle_management (
	$admin_password,
	$auth_url,
	$aristotle_mapping_name = 'aristotle',
	$aristotle_domain = 'aristotle',
) {
	class { 'aristotle_user_account':
		admin_password         => $admin_password,
		auth_url               => $auth_url,
		aristotle_mapping_name => $aristotle_mapping_name,
		aristotle_domain       => $aristotle_domain,
	}
}
