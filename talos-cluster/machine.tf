# Shared cluster secrets (CA + keys). This is the cluster identity — never let it
# be recreated, or every node will reject the new PKI.
resource "talos_machine_secrets" "this" {
  talos_version = var.talos_version
}

# ---------------------------------------------------------------------------
# Control-plane machine configuration
# ---------------------------------------------------------------------------
data "talos_machine_configuration" "controlplane" {
  for_each = local.cp_nodes

  cluster_name     = var.cluster_name
  machine_type     = "controlplane"
  cluster_endpoint = "https://${var.cluster_endpoint_ip}:6443"
  machine_secrets  = talos_machine_secrets.this.machine_secrets

  config_patches = concat([
    yamlencode({
      cluster = {
        # Cluster-wide switch; per-node opt-out is handled via nodeTaints below.
        allowSchedulingOnControlPlanes = local.any_cp_scheduling
        # Keep etcd peer/client traffic on the LAN. Without this, etcd may pick a
        # Netbird mesh address (100.96.x.x) as its advertised/peer address, which
        # breaks node-to-node operations (e.g. rotate-ca).
        etcd = {
          advertisedSubnets = [var.kubelet_valid_subnet]
          listenSubnets     = [var.kubelet_valid_subnet]
        }
      }
      machine = merge(
        {
          install = {
            image = local.installer_image
          }
          network = {
            interfaces = [
              {
                deviceSelector = {
                  physical = true
                }
                addresses = ["${each.value.ip_address}/${var.network_subnet}"]
                routes = [
                  {
                    network = "0.0.0.0/0"
                    gateway = var.network_gateway
                  }
                ]
                # Control-plane VIP for the shared Kubernetes API endpoint.
                vip = {
                  ip = var.cluster_endpoint_ip
                }
              }
            ]
          }
          # Netbird (hostNetwork) adds 100.96.x.x; kubelet must register the LAN IP
          # for metrics-server, exec, and port-forward (not the mesh address).
          kubelet = {
            nodeIP = {
              validSubnets = [var.kubelet_valid_subnet]
            }
          }
        },
        # Dedicated Longhorn data disk (omitted when the node has longhorn = false).
        each.value.longhorn ? {
          disks = [
            {
              device = var.longhorn_disk_device
              partitions = [
                {
                  mountpoint = "/var/lib/longhorn"
                }
              ]
            }
          ]
        } : {},
        # Manager-only control plane: re-add the control-plane NoSchedule taint that
        # allowSchedulingOnControlPlanes would otherwise remove cluster-wide.
        (local.any_cp_scheduling && !coalesce(each.value.allow_scheduling, true)) ? {
          nodeTaints = {
            "node-role.kubernetes.io/control-plane" = ":NoSchedule"
          }
        } : {}
      )
    }),

    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "HostnameConfig"
      auto       = "off"
      hostname   = each.value.name
    })
    ],
    [for patch in var.extra_config_patches : yamlencode(patch)]
  )
}

# ---------------------------------------------------------------------------
# Worker machine configuration (no VIP, no control-plane scheduling concerns)
# ---------------------------------------------------------------------------
data "talos_machine_configuration" "worker" {
  for_each = local.worker_nodes

  cluster_name     = var.cluster_name
  machine_type     = "worker"
  cluster_endpoint = "https://${var.cluster_endpoint_ip}:6443"
  machine_secrets  = talos_machine_secrets.this.machine_secrets

  config_patches = concat([
    yamlencode({
      machine = merge(
        {
          install = {
            image = local.installer_image
          }
          network = {
            interfaces = [
              {
                deviceSelector = {
                  physical = true
                }
                addresses = ["${each.value.ip_address}/${var.network_subnet}"]
                routes = [
                  {
                    network = "0.0.0.0/0"
                    gateway = var.network_gateway
                  }
                ]
              }
            ]
          }
          kubelet = {
            nodeIP = {
              validSubnets = [var.kubelet_valid_subnet]
            }
          }
        },
        each.value.longhorn ? {
          disks = [
            {
              device = var.longhorn_disk_device
              partitions = [
                {
                  mountpoint = "/var/lib/longhorn"
                }
              ]
            }
          ]
        } : {}
      )
    }),

    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "HostnameConfig"
      auto       = "off"
      hostname   = each.value.name
    })
    ],
    [for patch in var.extra_config_patches : yamlencode(patch)]
  )
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
