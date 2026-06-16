# Client configuration pointing at the VIP (used for the generated talosconfig).
data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = [var.cluster_endpoint_ip]
}

# Pull the kubeconfig from the first control plane after bootstrap.
resource "talos_cluster_kubeconfig" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.first_cp.ip_address

  depends_on = [talos_machine_bootstrap.this]
}

# Block downstream consumers (e.g. Flux) until the cluster is healthy.
data "talos_cluster_health" "health" {
  depends_on           = [talos_machine_bootstrap.this]
  client_configuration = talos_machine_secrets.this.client_configuration
  control_plane_nodes  = local.cp_node_ips
  worker_nodes         = local.worker_node_ips
  endpoints            = local.cp_node_ips

  timeouts = {
    read = "10m"
  }
}
