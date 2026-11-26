output "vm_ids" {
  description = "Map of node name => Proxmox VM ID."
  value       = { for k, vm in proxmox_virtual_environment_vm.nixos_node : k => vm.vm_id }
}

# Lean node list shaped for the nixos-anywhere-install module. `vm_id` is used as
# the install instance_id so replacing the VM forces a reinstall.
output "nixos_nodes" {
  description = "Nodes ready for nixos-anywhere-install (name, ip_address, vm_id)."
  value = [
    for n in var.nodes : {
      name       = n.name
      ip_address = n.ip_address
      vm_id      = proxmox_virtual_environment_vm.nixos_node[n.name].vm_id
    }
  ]
}
