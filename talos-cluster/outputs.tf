output "talosconfig" {
  description = "Rendered talosconfig (client config pointing at the VIP)."
  value       = data.talos_client_configuration.this.talos_config
  sensitive   = true
}

output "kubeconfig" {
  description = "Raw kubeconfig pulled from the cluster."
  value       = talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive   = true
}

output "kubernetes_client_configuration" {
  description = "Decoded Kubernetes client configuration (host + client/CA certs) for configuring downstream providers."
  value       = talos_cluster_kubeconfig.this.kubernetes_client_configuration
  sensitive   = true
}

output "client_configuration" {
  description = "Talos machine-secrets client configuration (for talosctl/data sources)."
  value       = talos_machine_secrets.this.client_configuration
  sensitive   = true
}

output "control_plane_nodes" {
  description = "Map of control-plane nodes (name => node object)."
  value       = local.cp_nodes
}

output "worker_nodes" {
  description = "Map of worker nodes (name => node object)."
  value       = local.worker_nodes
}

output "cluster_health_id" {
  description = "ID of the cluster-health check; depend on this to gate post-bootstrap resources."
  value       = data.talos_cluster_health.health.id
}
