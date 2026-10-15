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

Talos 1.14 generates a `KubeNodeConfig` document for each control plane. The
module removes its default `NoSchedule` taint only when `allow_scheduling = true`.
Nodes with `allow_scheduling = false` retain the default taint.

## Usage

```hcl
module "cluster" {
  source = "git::https://github.com/kreativmonkey/terraform-module.git//talos-cluster?ref=v0.5.0"

  cluster_name        = "homelab-kube"
  cluster_endpoint_ip = "192.168.10.245" # control-plane VIP
  talos_schematic_id  = "<image-factory-schematic-id>"
  talos_version       = "v1.14.2"
  kubernetes_version  = "1.36.0" # pin to the running cluster version

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
| `talos_version` | `v1.14.2` | Talos version and generated config contract; requires 1.14.x. |
| `secrets_talos_version` | `null` | Keep the original secrets contract when upgrading an existing cluster; defaults to `talos_version`. |
| `kubernetes_version` | `null` | Kubernetes component version in generated config; pin to the running version for existing clusters. |
| `install_disk` | `/dev/sda` | Existing Talos system disk for the unattended install selector. |
| `talos_schematic_id` | — | Image Factory schematic ID. |
| `image_platform` | `nocloud` | Builds the `<platform>-installer` reference. |
| `network_gateway` / `network_subnet` | `192.168.10.1` / `24` | Node networking. |
| `kubelet_valid_subnet` | `192.168.10.0/24` | LAN CIDR the kubelet registers from. |
| `nodes` | — | List of `{ name, ip_address, role?, allow_scheduling?, data_disks? }`, where `data_disks` is a list of `{ device, mountpoint }` (typically from `talos-proxmox-nodes`' `talos_nodes` output). |
| `extra_config_patches` | `[]` | YAML document patches applied to every node. |

The provider generates Talos 1.14's multi-document configuration. Node-specific
patches live in `patches/`, one file per topic, and are assembled in
`local.node_patches` (same order for control planes and workers):

| File | Document | Sets |
|---|---|---|
| `etcd.yaml.tftpl` | legacy `cluster.etcd` | LAN advertise/listen subnets (control planes only) |
| `network.yaml.tftpl` | legacy `machine.network` | static IP, default route, VIP (control planes only) |
| `disks.yaml.tftpl` | legacy `machine.disks` | data disk partitions |
| `kubelet.yaml.tftpl` | legacy `machine.kubelet` | image pin, `extraMounts`, seccomp default |
| `kubelet-config.yaml` | `KubeletConfig` | removed — conflicts with `machine.kubelet` |
| `install.yaml.tftpl` | `UnattendedInstallConfig` | installer image, system disk |
| `node.yaml.tftpl` | `KubeNodeConfig` | LAN node IP, control-plane taint removal |
| `hostname.yaml.tftpl` | `HostnameConfig` | static hostname |

Talos 1.14's `KubeletConfig` document does not expose `extraMounts`, so kubelet
stays in the legacy document; `defaultRuntimeSeccompProfileEnabled` and
`disableManifestsDirectory` restore what the removed document carried.
Cluster-wide documents (resolver, security profile, volumes, …) belong to the
caller via `extra_config_patches`, applied last.

## Outputs

`talosconfig`, `kubeconfig`, `kubernetes_client_configuration`,
`client_configuration`, `control_plane_nodes`, `worker_nodes`, `cluster_health_id`.

## Providers

Requires `siderolabs/talos` provider 0.12.x (configured by the caller).
