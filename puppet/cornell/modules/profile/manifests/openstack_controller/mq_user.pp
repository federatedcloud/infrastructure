define profile::openstack_controller::mq_user (
  $password,
  $admin = true,
  $vhost = '/',
) {
  rabbitmq_user { $name:
    admin    => $admin,
    password => $password,
    provider => 'rabbitmqctl',
    require  => Class['::rabbitmq'],
  }

  rabbitmq_user_permissions { "${name}@${vhost}":
    configure_permission => '.*',
    write_permission     => '.*',
    read_permission      => '.*',
    provider             => 'rabbitmqctl',
    require              => Class['::rabbitmq'],
  }

}

