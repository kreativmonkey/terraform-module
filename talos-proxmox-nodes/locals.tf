locals {
  nodes_map = { for n in var.nodes : n.name => n }

  # Effective Longhorn disk size per node (0 / null => no Longhorn disk).
  node_longhorn_gb = {
    for n in var.nodes : n.name => (
      n.longhorn_disk_gb != null ? n.longhorn_disk_gb : var.default_longhorn_disk_gb
    )
  }

  # ISO is downloaded once to shared storage; pick a stable host (lowest node name).
  names_sorted      = sort(keys(local.nodes_map))
  iso_download_node = local.nodes_map[local.names_sorted[0]].target_pve
}
