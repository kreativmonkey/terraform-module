resource "proxmox_virtual_environment_vm" "talos_node" {
  for_each = local.nodes_map

  description     = var.vm_description != null ? var.vm_description : file("${path.module}/talos-desc.html")
  name            = each.value.name
  tags            = ["terraform", "talos"]
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
    enabled = true # Important for Proxmox communication
  }

  network_device {
    bridge = var.network_bridge
  }

  # Mount the Talos ISO
  cdrom {
    file_id = proxmox_download_file.talos_iso.id
  }

  # Main OS disk
  disk {
    datastore_id = local.node_storage_id[each.key]
    file_format  = "raw"
    interface    = "scsi0"
    size         = coalesce(each.value.disk_gb, var.default_disk_gb)
  }

  # Named data disks (each mounted by the talos-cluster module at its mountpoint).
  # Attached on scsi1, scsi2, … in list order.
  dynamic "disk" {
    for_each = local.node_data_disks_resolved[each.key]
    iterator = data_disk
    content {
      datastore_id = coalesce(data_disk.value.datastore_id, local.node_storage_id[each.key])
      file_format  = "raw"
      interface    = data_disk.value.interface
      size         = data_disk.value.size_gb
    }
  }

  # Raw extra disks (created but NOT mounted by Talos). Attached after the data
  # disks so their default scsi slots don't collide.
  dynamic "disk" {
    for_each = each.value.extra_disks
    iterator = extra_disk
    content {
      datastore_id = coalesce(extra_disk.value.datastore_id, local.node_storage_id[each.key])
      file_format  = "raw"
      interface    = coalesce(extra_disk.value.interface, "scsi${1 + length(local.node_data_disks_resolved[each.key]) + extra_disk.index}")
      size         = extra_disk.value.size
    }
  }

  operating_system {
    type = "l26" # Linux Kernel 2.6+
  }

  boot_order = [
    "scsi0", # Main disk first
    "ide3",  # ISO as fallback for initial installation
    "net0"
  ]

  initialization {
    datastore_id = local.node_storage_id[each.key]
    ip_config {
      ipv4 {
        address = "${each.value.ip_address}/${var.network_subnet}"
        gateway = var.network_gateway
      }
      ipv6 {
        address = "dhcp"
      }
    }
  }
}
