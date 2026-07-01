locals {
  nodes_map = { for n in var.nodes : n.name => n }

  # Index the provided public keys so each becomes one hcloud_ssh_key.
  ssh_keys = { for i, k in var.ssh_public_keys : "${var.ssh_key_name_prefix}-${i}" => k }
}

resource "hcloud_ssh_key" "this" {
  for_each   = local.ssh_keys
  name       = each.key
  public_key = each.value
}

resource "hcloud_server" "nixos_node" {
  for_each = local.nodes_map

  name        = each.value.name
  server_type = coalesce(each.value.server_type, var.default_server_type)
  location    = coalesce(each.value.location, var.default_location)
  image       = var.bootstrap_image
  ssh_keys    = [for k in hcloud_ssh_key.this : k.id]

  labels = merge({ managed_by = "opentofu", os = "nixos" }, each.value.labels)

  public_net {
    ipv4_enabled = var.enable_ipv4
    ipv6_enabled = true
  }

  # The image and any cloud-init state here are disposable: nixos-anywhere kexecs
  # into the NixOS installer and repartitions the disk. Ignore image drift so a
  # newer Debian base never triggers a destroy/recreate of an installed node.
  lifecycle {
    ignore_changes = [image, ssh_keys]
  }
}
