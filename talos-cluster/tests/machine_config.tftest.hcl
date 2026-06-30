# Validates that the generated Talos machine configuration decodes against the
# Talos schema. The talos_machine_configuration data sources run for real but
# fully offline (local generation + schema validation), so an invalid config
# patch — like the former machine.api.advertisedAddresses — fails this run.
#
# Every network-touching resource/data source (config apply, bootstrap,
# kubeconfig pull, cluster health) is overridden, so the test needs no reachable
# nodes and no credentials.

variables {
  cluster_name        = "test-cluster"
  cluster_endpoint_ip = "192.168.10.10"
  talos_schematic_id  = "376567988ad370138ad8b2698212367b8edcb69b5fd8c70079e8fa3a36cd4ca5"

  nodes = [
    {
      name             = "cp1"
      ip_address       = "192.168.10.11"
      role             = "controlplane"
      allow_scheduling = false # manager-only: exercises the nodeTaints branch
      data_disks       = []    # no data disks
    },
    {
      name       = "cp2"
      ip_address = "192.168.10.12"
      role       = "controlplane"
      # exercises the multi data-disk branch
      data_disks = [
        { device = "/dev/sdb", mountpoint = "/var/mnt/cnpg" },
        { device = "/dev/sdc", mountpoint = "/var/lib/longhorn" },
      ]
    },
    {
      name       = "wrk1"
      ip_address = "192.168.10.21"
      role       = "worker"
      data_disks = [{ device = "/dev/sdb", mountpoint = "/var/mnt/data" }]
    },
  ]
}

override_resource {
  target = talos_machine_configuration_apply.cp
}

override_resource {
  target = talos_machine_configuration_apply.worker
}

override_resource {
  target = talos_machine_bootstrap.this
}

override_resource {
  target = talos_cluster_kubeconfig.this
}

override_data {
  target = data.talos_cluster_health.health
}

run "machine_config_is_valid" {
  command = apply

  assert {
    condition     = length(output.control_plane_nodes) == 2
    error_message = "Expected 2 control-plane nodes in the generated configuration."
  }

  assert {
    condition     = length(output.worker_nodes) == 1
    error_message = "Expected 1 worker node in the generated configuration."
  }
}
