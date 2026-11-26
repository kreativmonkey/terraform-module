locals {
  nodes_map = { for n in var.nodes : n.name => n }

  # Effective datastore per node (per-node storage_id overrides vm_storage_id).
  node_storage_id = {
    for n in var.nodes : n.name => coalesce(n.storage_id, var.vm_storage_id)
  }

  # Keep the download node fixed when the VM list changes.
  names_sorted      = sort(keys(local.nodes_map))
  iso_download_node = var.bootstrap_pve != null ? var.bootstrap_pve : local.nodes_map[local.names_sorted[0]].target_pve
}
