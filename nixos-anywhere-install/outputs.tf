output "installed_hosts" {
  description = "Map of hostname => target_host actually installed."
  value       = { for k, h in local.hosts_map : k => h.target_host }
}

output "result" {
  description = "Raw result objects from the nixos-anywhere all-in-one module, keyed by hostname (depend on this to gate colmena/day-2 steps)."
  value       = { for k, m in module.install : k => m }
}
