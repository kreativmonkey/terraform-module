output "vm_ids" {
  description = "Map of node name => Proxmox VM ID."
  value       = { for k, vm in proxmox_virtual_environment_vm.talos_node : k => vm.vm_id }
}

output "iso_file_id" {
  description = "File ID of the downloaded Talos ISO."
  value       = proxmox_download_file.talos_iso.id
}

# Lean node list for the talos-cluster module (keeps the data-disk -> device
# resolution in one place). The env adds an explicit depends_on so the Talos
# config is only applied after the VMs exist.
output "talos_nodes" {
  description = "Nodes ready for the talos-cluster module (name, ip, role, scheduling, data_disks with resolved device + mountpoint)."
  value = [
    for n in var.nodes : {
      name             = n.name
      ip_address       = n.ip_address
      role             = n.role
      allow_scheduling = n.allow_scheduling
      data_disks = [
        for d in local.node_data_disks_resolved[n.name] : {
          device     = d.device
          mountpoint = d.mountpoint
        }
      ]
    }
  ]
}
