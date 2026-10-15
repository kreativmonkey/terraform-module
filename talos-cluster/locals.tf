locals {
  cp_nodes     = { for n in var.nodes : n.name => n if n.role == "controlplane" }
  worker_nodes = { for n in var.nodes : n.name => n if n.role == "worker" }

  cp_node_ips     = sort([for n in local.cp_nodes : n.ip_address])
  worker_node_ips = sort([for n in local.worker_nodes : n.ip_address])

  # Deterministic "first" control plane (lowest name) used for the one-off
  # bootstrap and the kubeconfig pull. Sorting keeps this stable across applies.
  cp_names_sorted = sort(keys(local.cp_nodes))
  first_cp        = local.cp_nodes[local.cp_names_sorted[0]]

  installer_image = "factory.talos.dev/${var.image_platform}-installer/${var.talos_schematic_id}:${var.talos_version}"
}
