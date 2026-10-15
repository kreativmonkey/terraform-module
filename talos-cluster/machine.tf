# Shared cluster secrets (CA + keys). This is the cluster identity — never let it
# be recreated, or every node will reject the new PKI.
resource "talos_machine_secrets" "this" {
  talos_version = coalesce(var.secrets_talos_version, var.talos_version)
}

# ---------------------------------------------------------------------------
# Control-plane machine configuration
# ---------------------------------------------------------------------------
data "talos_machine_configuration" "controlplane" {
  for_each = local.cp_nodes

  cluster_name       = var.cluster_name
  machine_type       = "controlplane"
  cluster_endpoint   = "https://${var.cluster_endpoint_ip}:6443"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version

  config_patches = concat([
    yamlencode({
      cluster = {
        # Keep etcd peer/client traffic on the LAN. Without this, etcd may pick a
        # Netbird mesh address (100.96.x.x) as its advertised/peer address, which
        # breaks node-to-node operations (e.g. rotate-ca). advertisedSubnets may
        # carry explicit excludes (e.g. "!100.64.0.0/10") via etcd_advertised_subnets.
        etcd = {
          advertisedSubnets = coalesce(var.etcd_advertised_subnets, [var.kubelet_valid_subnet])
          listenSubnets     = [var.kubelet_valid_subnet]
        }
      }
      machine = {
        network = {
          interfaces = [
            {
              deviceSelector = { physical = true }
              addresses      = ["${each.value.ip_address}/${var.network_subnet}"]
              routes         = [{ network = "0.0.0.0/0", gateway = var.network_gateway }]
              vip            = { ip = var.cluster_endpoint_ip }
            }
          ]
        }
        disks = [for d in each.value.data_disks : {
          device     = d.device
          partitions = [{ mountpoint = d.mountpoint }]
        }]
        kubelet = merge({
          extraMounts = [for d in each.value.data_disks : {
            destination = d.mountpoint
            source      = d.mountpoint
            type        = "bind"
            options     = ["bind", "rshared", "rw"]
          }]
          }, var.kubernetes_version == null ? {} : {
          image = "ghcr.io/siderolabs/kubelet:v${var.kubernetes_version}"
        })
      }
    }),

    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "UnattendedInstallConfig"
      installer  = { image = local.installer_image }
      provisioning = {
        diskSelector = { match = "disk.dev_path == \"${var.install_disk}\"" }
      }
    }),

    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "KubeletConfig"
      "$patch"   = "delete"
    }),

    yamlencode(merge({
      apiVersion = "v1alpha1"
      kind       = "KubeNodeConfig"
      # Netbird adds a mesh IP; kubelet must register the LAN IP.
      nodeIP = { validSubnets = [var.kubelet_valid_subnet] }
      }, coalesce(each.value.allow_scheduling, true) ? {
      taints = {
        "node-role.kubernetes.io/control-plane" = { "$patch" = "delete" }
      }
    } : {})),

    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "HostnameConfig"
      auto       = "off"
      hostname   = each.value.name
    })
    ],
    var.extra_config_patches
  )
}

# ---------------------------------------------------------------------------
# Worker machine configuration (no VIP, no control-plane scheduling concerns)
# ---------------------------------------------------------------------------
data "talos_machine_configuration" "worker" {
  for_each = local.worker_nodes

  cluster_name       = var.cluster_name
  machine_type       = "worker"
  cluster_endpoint   = "https://${var.cluster_endpoint_ip}:6443"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version

  config_patches = concat([
    yamlencode({
      machine = {
        network = {
          interfaces = [
            {
              deviceSelector = { physical = true }
              addresses      = ["${each.value.ip_address}/${var.network_subnet}"]
              routes         = [{ network = "0.0.0.0/0", gateway = var.network_gateway }]
            }
          ]
        }
        disks = [for d in each.value.data_disks : {
          device     = d.device
          partitions = [{ mountpoint = d.mountpoint }]
        }]
        kubelet = merge({
          extraMounts = [for d in each.value.data_disks : {
            destination = d.mountpoint
            source      = d.mountpoint
            type        = "bind"
            options     = ["bind", "rshared", "rw"]
          }]
          }, var.kubernetes_version == null ? {} : {
          image = "ghcr.io/siderolabs/kubelet:v${var.kubernetes_version}"
        })
      }
    }),

    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "UnattendedInstallConfig"
      installer  = { image = local.installer_image }
      provisioning = {
        diskSelector = { match = "disk.dev_path == \"${var.install_disk}\"" }
      }
    }),

    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "KubeletConfig"
      "$patch"   = "delete"
    }),

    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "KubeNodeConfig"
      nodeIP     = { validSubnets = [var.kubelet_valid_subnet] }
    }),

    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "HostnameConfig"
      auto       = "off"
      hostname   = each.value.name
    })
    ],
    var.extra_config_patches
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
