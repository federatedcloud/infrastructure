class profile::openstack_controller::cinder_pacemaker {

            Pacemaker_resource<| tag == 'ha_stage_2' |> -> Pacemaker_order<| tag == 'ha_stage_2' |>
            Pacemaker_resource<| tag == 'ha_stage_2' |> -> Pacemaker_colocation<| tag == 'ha_stage_2' |>

            pacemaker_resource { "openstack-cinder-api":
               ensure => 'present',
               primitive_class => 'systemd',
               primitive_type => 'openstack-cinder-api',
               complex_type => "clone",
               complex_metadata => {
                'interleave' => true,
               },
               tag    => ['ha_stage_2'],
            }

            pacemaker_resource { "openstack-cinder-scheduler":
               ensure => 'present',
               primitive_class => 'systemd',
               primitive_type => 'openstack-cinder-scheduler',
               complex_type => "clone",
               complex_metadata => {
                'interleave' => true,
               },
               operations => {"start" => { "timeout" => "90s"}, "stop" => { "timeout" => "90s"}},
               tag    => ['ha_stage_2'],
            }

            # Volume must be A/P
            pacemaker_resource { "openstack-cinder-volume":
               ensure => 'present',
               primitive_class => 'systemd',
               primitive_type => 'openstack-cinder-volume',
               operations => {"start" => { "timeout" => "90s"}, "stop" => { "timeout" => "90s"}},
               tag    => ['ha_stage_2'],
            }

            pacemaker_order { 'cinder1-order' :
              first         => 'openstack-cinder-api-clone',
              first_action  => 'start',
              second        => 'openstack-cinder-scheduler-clone',
               tag    => ['ha_stage_2'],
            }

            pacemaker_colocation { 'cinder1-colo' :
              first  => 'openstack-cinder-scheduler-clone',
              second => 'openstack-cinder-api-clone',
               tag    => ['ha_stage_2'],
            }

            pacemaker_order { 'cinder2-order' :
              first         => 'openstack-cinder-scheduler-clone',
              first_action  => 'start',
              second        => 'openstack-cinder-volume',
               tag    => ['ha_stage_2'],
            }

            pacemaker_colocation { 'cinder2-colo' :
              first  => 'openstack-cinder-volume',
              second => 'openstack-cinder-scheduler-clone',
               tag    => ['ha_stage_2'],
            }

            # Cron on only one node colocate on the cinder node to make it easy to track
            pacemaker_resource { "cinder-audit-cron-symlink":
               ensure => 'present',
               primitive_class => 'ocf',
               primitive_provider => 'heartbeat',
               primitive_type => 'symlink',
               parameters => {
                    'target' => '/etc/cinder/cinder-volume-usage-audit-cron',
                    'link' => '/etc/cron.d/cinder-volume-usage-audit-cron',
               },
               tag    => ['ha_stage_2'],
            }

            pacemaker_colocation { 'cinder-audit-cron-symlink-colo' :
              first  => 'openstack-cinder-volume',
              second => 'cinder-audit-cron-symlink',
               tag    => ['ha_stage_2'],
            }
}
