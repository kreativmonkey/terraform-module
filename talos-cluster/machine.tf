# Shared cluster secrets (CA + keys). This is the cluster identity — never let it
# be recreated, or every node will reject the new PKI.
resource "talos_machine_secrets" "this" {
  talos_version = coalesce(var.secrets_talos_version, var.talos_version)
}

# ---------------------------------------------------------------------------
# Machine configuration
# ---------------------------------------------------------------------------
# Node-specific patches live in patches/, one file per topic; local.node_patches
# assembles them. Cluster-wide documents come from var.extra_config_patches.
data "talos_machine_configuration" "controlplane" {
  for_each = local.cp_nodes

  cluster_name       = var.cluster_name
  machine_type       = "controlplane"
  cluster_endpoint   = "https://${var.cluster_endpoint_ip}:6443"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version

  config_patches = local.node_patches[each.key]
}

data "talos_machine_configuration" "worker" {
  for_each = local.worker_nodes

  cluster_name       = var.cluster_name
  machine_type       = "worker"
  cluster_endpoint   = "https://${var.cluster_endpoint_ip}:6443"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version

  config_patches = local.node_patches[each.key]
}

# ---------------------------------------------------------------------------
# Apply configuration to each node
# ---------------------------------------------------------------------------
resource "talos_machine_configuration_apply" "cp" {
  for_each = local.cp_nodes

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane[each.key].machine_configuration

  node     = each.value.ip_address
  endpoint = each.value.ip_address
}

resource "talos_machine_configuration_apply" "worker" {
  for_each = local.worker_nodes

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker[each.key].machine_configuration

  node     = each.value.ip_address
  endpoint = each.value.ip_address
}

# Bootstrap etcd exactly once, on the first control plane.
resource "talos_machine_bootstrap" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration

  node     = local.first_cp.ip_address
  endpoint = local.first_cp.ip_address

  depends_on = [talos_machine_configuration_apply.cp]
}
