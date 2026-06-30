# terraform-talos-cluster

Platform-agnostic OpenTofu/Terraform module that configures a [Talos
Linux](https://www.talos.dev/) Kubernetes cluster on nodes that are **already
reachable** (in maintenance mode) at known IPs. It does not provision machines —
pair it with any node source (Proxmox, bare metal, vSphere, …).

It handles: machine secrets, per-node control-plane/worker machine configuration,
config apply, one-off `etcd` bootstrap, kubeconfig retrieval and a cluster-health
gate.

## Node roles

| `role` | `allow_scheduling` | result |
|---|---|---|
| `controlplane` | `true` | manager **and** worker (runs workloads) |
| `controlplane` | `false` | manager only (control-plane `NoSchedule` taint) |
| `worker` | — | dedicated worker (no VIP, schedulable) |

`allowSchedulingOnControlPlanes` is enabled cluster-wide as soon as **any** control
plane schedules; manager-only control planes are individually tainted via
`machine.nodeTaints`.

## Usage

```hcl
module "cluster" {
  source = "git::https://github.com/kreativmonkey/terraform-module.git//talos-cluster?ref=v0.1.0"

  cluster_name        = "homelab-kube"
  cluster_endpoint_ip = "192.168.10.245" # control-plane VIP
  talos_schematic_id  = "<image-factory-schematic-id>"

  nodes = [
    { name = "talos-cp1", ip_address = "192.168.10.41", role = "controlplane", allow_scheduling = true },
    { name = "talos-cp2", ip_address = "192.168.10.42", role = "controlplane", allow_scheduling = true },
    { name = "talos-cp3", ip_address = "192.168.10.43", role = "controlplane", allow_scheduling = true },
    # { name = "talos-wrk1", ip_address = "192.168.10.51", role = "worker" },
  ]
}
```

The node IPs must be reachable and booted into Talos maintenance mode before apply
(e.g. provide them via a `talos-proxmox-nodes`-style module and `depends_on`).

## Key inputs

| Name | Default | Description |
|---|---|---|
| `cluster_name` | — | Cluster name. |
| `cluster_endpoint_ip` | — | Control-plane VIP / Kubernetes API endpoint. |
| `talos_version` | `v1.13.2` | Talos version. |
| `talos_schematic_id` | — | Image Factory schematic ID. |
| `image_platform` | `nocloud` | Builds the `<platform>-installer` reference. |
| `network_gateway` / `network_subnet` | `192.168.10.1` / `24` | Node networking. |
| `kubelet_valid_subnet` | `192.168.10.0/24` | LAN CIDR the kubelet registers from. |
| `nodes` | — | List of `{ name, ip_address, role?, allow_scheduling?, data_disks? }`, where `data_disks` is a list of `{ device, mountpoint }` (typically from `talos-proxmox-nodes`' `talos_nodes` output). |
| `extra_config_patches` | `[]` | Extra Talos config patches applied to every node. |

## Outputs

`talosconfig`, `kubeconfig`, `kubernetes_client_configuration`,
`client_configuration`, `control_plane_nodes`, `worker_nodes`, `cluster_health_id`.

## Providers

Requires only the `siderolabs/talos` provider (configured by the caller).
