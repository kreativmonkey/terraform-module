output "server_ids" {
  description = "Map of node name => Hetzner server ID."
  value       = { for k, s in hcloud_server.nixos_node : k => s.id }
}

# Lean node list shaped for the nixos-anywhere-install module. Prefers the public
# IPv4; falls back to IPv6 when IPv4 is disabled. server_id is used as the install
# instance_id so replacing the server forces a reinstall.
output "nixos_nodes" {
  description = "Nodes ready for nixos-anywhere-install (name, ip_address, server_id)."
  value = [
    for n in var.nodes : {
      name       = n.name
      ip_address = var.enable_ipv4 ? hcloud_server.nixos_node[n.name].ipv4_address : hcloud_server.nixos_node[n.name].ipv6_address
      server_id  = hcloud_server.nixos_node[n.name].id
    }
  ]
}
