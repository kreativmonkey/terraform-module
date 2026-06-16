# terraform-module

A small collection of OpenTofu/Terraform modules used to bring up a
[Talos Linux](https://www.talos.dev/) Kubernetes cluster on Proxmox. The two
modules are deliberately split by responsibility so they can be combined or
swapped independently:

| Module | Responsibility | Provider |
|---|---|---|
| [`proxmox-nodes`](./proxmox-nodes) | Provisions the VMs (and downloads the Talos ISO) on Proxmox. | `bpg/proxmox` |
| [`talos-cluster`](./talos-cluster) | Configures Talos + bootstraps the Kubernetes cluster on nodes that are already reachable. **Platform-agnostic.** | `siderolabs/talos` |

`talos-cluster` does **not** create machines — it only configures Talos on nodes
that are already booted into maintenance mode at known IPs. That keeps it
reusable for any node source (Proxmox, bare metal, vSphere, …). `proxmox-nodes`
is the matching node source for a Proxmox homelab and emits a `talos_nodes`
output shaped exactly for `talos-cluster`'s `nodes` input.

## Requirements

- OpenTofu `>= 1.6.0` (or Terraform)
- Providers (configured by the caller): `bpg/proxmox >= 0.66.0`,
  `siderolabs/talos >= 0.6.0`
- A [Talos Image Factory](https://factory.talos.dev/) schematic ID for the
  system extensions you need (e.g. `qemu-guest-agent`, `iscsi-tools`)

## Module sources

Reference a module by sub-directory and pin a tag with `?ref=`:

```hcl
source = "git::https://github.com/kreativmonkey/terraform-module.git//talos-cluster?ref=v0.1.0"
source = "git::https://github.com/kreativmonkey/terraform-module.git//proxmox-nodes?ref=v0.1.0"
```

## Example — Proxmox + Talos end to end

Provision the VMs with `proxmox-nodes`, then feed its `talos_nodes` output into
`talos-cluster`. The `depends_on` makes sure Talos is only configured after the
VMs exist and are reachable.

```hcl
terraform {
  required_providers {
    proxmox = { source = "bpg/proxmox", version = ">= 0.66.0" }
    talos   = { source = "siderolabs/talos", version = ">= 0.6.0" }
  }
}

provider "proxmox" {
  endpoint  = "https://192.168.10.10:8006"
  api_token = var.proxmox_api_token # user@pam!token=uuid
  insecure  = true
}

provider "talos" {}

locals {
  talos_version      = "v1.13.2"
  talos_schematic_id = "<image-factory-schematic-id>"

  nodes = [
    { name = "talos-cp1", target_pve = "pve1", ip_address = "192.168.10.41", role = "controlplane", allow_scheduling = true },
    { name = "talos-cp2", target_pve = "pve2", ip_address = "192.168.10.42", role = "controlplane", allow_scheduling = true },
    { name = "talos-cp3", target_pve = "pve3", ip_address = "192.168.10.43", role = "controlplane", allow_scheduling = true },
    # { name = "talos-wrk1", target_pve = "pve1", ip_address = "192.168.10.51", role = "worker" },
  ]
}

# 1. Provision the Proxmox VMs.
module "nodes" {
  source = "git::https://github.com/kreativmonkey/terraform-module.git//proxmox-nodes?ref=v0.1.0"

  nodes              = local.nodes
  talos_version      = local.talos_version
  talos_schematic_id = local.talos_schematic_id

  vm_storage_id  = "local-lvm"
  iso_storage_id = "NFS-Storage" # shared storage so one ISO download reaches every node
}

# 2. Configure Talos on those VMs and bootstrap the cluster.
module "cluster" {
  source = "git::https://github.com/kreativmonkey/terraform-module.git//talos-cluster?ref=v0.1.0"

  cluster_name        = "homelab-kube"
  cluster_endpoint_ip = "192.168.10.245" # control-plane VIP
  talos_version       = local.talos_version
  talos_schematic_id  = local.talos_schematic_id

  nodes = module.nodes.talos_nodes

  # Only configure Talos after the VMs exist and are reachable.
  depends_on = [module.nodes]
}

output "kubeconfig" {
  value     = module.cluster.kubeconfig
  sensitive = true
}

output "talosconfig" {
  value     = module.cluster.talosconfig
  sensitive = true
}
```

### Node roles

| `role` | `allow_scheduling` | result |
|---|---|---|
| `controlplane` | `true` | manager **and** worker (runs workloads) |
| `controlplane` | `false` | manager only (control-plane `NoSchedule` taint) |
| `worker` | — | dedicated worker (always schedulable) |

See each module's own README for the full input/output reference:
[`proxmox-nodes`](./proxmox-nodes/README.md) ·
[`talos-cluster`](./talos-cluster/README.md).

## Wiring downstream providers (kubernetes / helm / flux)

`talos-cluster` exposes `kubernetes_client_configuration` so you can configure
Kubernetes-facing providers off the freshly bootstrapped cluster:

```hcl
provider "kubernetes" {
  host                   = module.cluster.kubernetes_client_configuration.host
  client_certificate     = base64decode(module.cluster.kubernetes_client_configuration.client_certificate)
  client_key             = base64decode(module.cluster.kubernetes_client_configuration.client_key)
  cluster_ca_certificate = base64decode(module.cluster.kubernetes_client_configuration.ca_certificate)
}
```

Gate any post-bootstrap resources on `module.cluster.cluster_health_id` so they
only run once the cluster reports healthy.
