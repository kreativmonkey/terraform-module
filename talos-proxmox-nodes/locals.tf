locals {
  nodes_map = { for n in var.nodes : n.name => n }

  # Effective datastore per node (per-node storage_id overrides vm_storage_id).
  node_storage_id = {
    for n in var.nodes : n.name => coalesce(n.storage_id, var.vm_storage_id)
  }

  # Effective data disks per node (node.data_disks overrides the module default;
  # null => inherit var.default_data_disks, [] => explicitly none).
  node_data_disks = {
    for n in var.nodes : n.name => (
      n.data_disks != null ? n.data_disks : var.default_data_disks
    )
  }

  # Resolve the guest device + Proxmox interface for each data disk. Data disks
  # occupy scsi1..scsiN (the OS disk is scsi0 => /dev/sda). virtio-scsi disks
  # enumerate in slot order at boot, before any iSCSI volumes attach, so scsi(1+i)
  # is deterministically /dev/sd<b+i>.
  disk_letters = "bcdefghijklmnopqrstuvwxyz"
  node_data_disks_resolved = {
    for name, disks in local.node_data_disks : name => [
      for i, d in disks : {
        name         = d.name
        size_gb      = d.size_gb
        mountpoint   = d.mountpoint
        datastore_id = d.datastore_id
        interface    = "scsi${1 + i}"
        device       = "/dev/sd${substr(local.disk_letters, i, 1)}"
      }
    ]
  }

  # ISO is downloaded once to shared storage; pick a stable host (lowest node name).
  names_sorted      = sort(keys(local.nodes_map))
  iso_download_node = local.nodes_map[local.names_sorted[0]].target_pve
}
