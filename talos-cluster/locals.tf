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

locals {
  # Ordered Talos config patches per node: legacy v1alpha1 sections first, then
  # multi-document patches, then the caller's cluster-wide documents.
  node_patches = {
    for name, n in merge(local.cp_nodes, local.worker_nodes) : name => concat(
      n.role == "controlplane" ? [templatefile("${path.module}/patches/etcd.yaml.tftpl", {
        advertised_subnets = coalesce(var.etcd_advertised_subnets, [var.kubelet_valid_subnet])
        listen_subnets     = [var.kubelet_valid_subnet]
      })] : [],
      [
        templatefile("${path.module}/patches/network.yaml.tftpl", {
          address = "${n.ip_address}/${var.network_subnet}"
          gateway = var.network_gateway
          vip     = n.role == "controlplane" ? var.cluster_endpoint_ip : null
        }),
        templatefile("${path.module}/patches/disks.yaml.tftpl", {
          data_disks = n.data_disks
        }),
        templatefile("${path.module}/patches/kubelet.yaml.tftpl", {
          image      = var.kubernetes_version == null ? null : "ghcr.io/siderolabs/kubelet:v${var.kubernetes_version}"
          data_disks = n.data_disks
        }),
        file("${path.module}/patches/kubelet-config.yaml"),
        templatefile("${path.module}/patches/install.yaml.tftpl", {
          installer_image = local.installer_image
          install_disk    = var.install_disk
        }),
        templatefile("${path.module}/patches/node.yaml.tftpl", {
          valid_subnet     = var.kubelet_valid_subnet
          allow_scheduling = n.role == "controlplane" && coalesce(n.allow_scheduling, true)
        }),
        templatefile("${path.module}/patches/hostname.yaml.tftpl", {
          hostname = n.name
        }),
      ],
      var.extra_config_patches,
    )
  }
}
