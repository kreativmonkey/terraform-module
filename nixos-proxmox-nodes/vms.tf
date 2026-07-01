resource "proxmox_virtual_environment_vm" "nixos_node" {
  for_each = local.nodes_map

  description     = "NixOS node (bootstrapped via nixos-anywhere). Managed by OpenTofu."
  name            = each.value.name
  tags            = ["terraform", "nixos"]
  node_name       = each.value.target_pve
  on_boot         = true
  stop_on_destroy = true

  cpu {
    cores   = coalesce(each.value.cpu_cores, var.default_cpu_cores)
    sockets = coalesce(each.value.cpu_sockets, var.default_cpu_sockets)
    type    = coalesce(each.value.cpu_type, var.default_cpu_type)
  }

  memory {
    dedicated = coalesce(each.value.memory_mb, var.default_memory_mb)
  }

  agent {
    enabled = true # qemu-guest-agent is enabled in the NixOS config post-install.
  }

  network_device {
    bridge = var.network_bridge
  }

  # Import the bootstrap cloud image as the main OS disk. nixos-anywhere later
  # repartitions this disk with disko and installs NixOS onto it.
  disk {
    datastore_id = local.node_storage_id[each.key]
    import_from  = proxmox_download_file.bootstrap.id
    file_format  = "raw"
    interface    = "scsi0"
    size         = coalesce(each.value.disk_gb, var.default_disk_gb)
  }

  operating_system {
    type = "l26" # Linux Kernel 2.6+
  }

  boot_order = ["scsi0"]

  # cloud-init: static IP + authorized SSH keys so nixos-anywhere can connect to
  # the bootstrap distro. Discarded once NixOS is installed.
  initialization {
    datastore_id = local.node_storage_id[each.key]

    dns {
      servers = [var.nameserver]
    }

    user_account {
      username = var.bootstrap_user
      keys     = var.ssh_public_keys
    }

    ip_config {
      ipv4 {
        address = "${each.value.ip_address}/${var.network_subnet}"
        gateway = var.network_gateway
      }
    }
  }
}
