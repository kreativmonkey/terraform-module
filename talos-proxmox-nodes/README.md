# talos-proxmox-nodes

OpenTofu/Terraform module that provisions Proxmox VMs to back Talos nodes and
downloads the Talos ISO to (shared) Proxmox storage. It **only creates the
machines** — the Talos cluster itself is configured by the platform-agnostic
[`talos-cluster`](../talos-cluster) module.

Its `talos_nodes` output is shaped exactly for `talos-cluster`'s `nodes` input
(it resolves each named data disk to its guest device and passes the
`{ device, mountpoint }` pairs through).

## Usage

```hcl
module "nodes" {
  source = "git::https://github.com/kreativmonkey/terraform-module.git//talos-proxmox-nodes?ref=v0.1.0"

  talos_schematic_id = "<image-factory-schematic-id>"

  vm_storage_id  = "local-lvm"
  iso_storage_id = "NFS-Storage" # shared storage: one ISO download reaches every node

  # Named data disks created on every node (override per node via node.data_disks).
  default_data_disks = [
    { name = "cnpg", size_gb = 20, mountpoint = "/var/mnt/cnpg" },
    { name = "longhorn", size_gb = 80, mountpoint = "/var/lib/longhorn" },
  ]

  nodes = [
    { name = "talos-cp1", target_pve = "pve1", ip_address = "192.168.10.41", role = "controlplane", allow_scheduling = true },
    { name = "talos-cp2", target_pve = "pve2", ip_address = "192.168.10.42", role = "controlplane", allow_scheduling = true },
    { name = "talos-cp3", target_pve = "pve3", ip_address = "192.168.10.43", role = "controlplane", allow_scheduling = true, cpu_sockets = 2 },
    # A worker with no data disks (overrides the module default):
    # { name = "talos-wrk1", target_pve = "pve1", ip_address = "192.168.10.51", role = "worker", data_disks = [] },
  ]
}
```

The `proxmox` provider must be configured by the caller.

## Inputs

| Name | Default | Description |
|---|---|---|
| `nodes` | — | List of nodes to provision (see below). |
| `talos_schematic_id` | — | Talos Image Factory schematic ID (used to build the ISO URL). |
| `talos_version` | `v1.13.2` | Talos version. |
| `image_platform` / `image_arch` | `nocloud` / `amd64` | Used to build the ISO URL. |
| `vm_storage_id` | `local-lvm` | Datastore for the VM disks. |
| `iso_storage_id` | `NFS-Storage` | Datastore for the ISO. Use shared storage so one download reaches every node. |
| `network_gateway` / `network_subnet` | `192.168.10.1` / `24` | Node networking. |
| `network_bridge` | `vmbr0` | Proxmox bridge for the VM NIC. |
| `vm_description` | bundled `talos-desc.html` | Description set on the VMs. |
| `default_cpu_cores` | `2` | Per-node CPU cores (overridable per node). |
| `default_cpu_sockets` | `1` | Per-node CPU sockets. |
| `default_cpu_type` | `x86-64-v2-AES` | Per-node CPU type. |
| `default_memory_mb` | `4096` | Per-node memory. |
| `default_disk_gb` | `20` | Per-node OS disk size. |
| `default_data_disks` | `[]` | Named data disks created on every node: list of `{ name, size_gb, mountpoint, datastore_id? }`. Each becomes a Proxmox disk + a Talos mount. Override per node via `node.data_disks`. |

### `nodes` object

| Field | Required | Description |
|---|---|---|
| `name` | yes | VM name (must be unique). |
| `target_pve` | yes | Proxmox node to place the VM on. |
| `ip_address` | yes | Static IPv4 (no CIDR). |
| `role` | no (`controlplane`) | Passed through to `talos_nodes`. |
| `allow_scheduling` | no | Passed through to `talos_nodes` (controlplane only). |
| `cpu_cores` / `cpu_sockets` / `cpu_type` / `memory_mb` / `disk_gb` | no | Per-node overrides of the `default_*` values. |
| `data_disks` | no | Named data disks for this node: list of `{ name, size_gb, mountpoint, datastore_id? }`. `null` (unset) inherits `default_data_disks`; `[]` means none. Attached on scsi1, scsi2, … in order. |
| `storage_id` | no | Datastore for this node's main + data disks and cloud-init drive. Overrides `vm_storage_id` (e.g. a host that exposes `local_storage` instead of `local-lvm`). |
| `extra_disks` | no (`[]`) | Raw disks created but **not** mounted by Talos: `{ size, datastore_id?, interface? }`. Attached after the data disks. |

## Outputs

| Name | Description |
|---|---|
| `talos_nodes` | Node list ready for the `talos-cluster` module's `nodes` input. |
| `vm_ids` | Map of node name => Proxmox VM ID. |
| `iso_file_id` | File ID of the downloaded Talos ISO. |

## Providers

Requires only the `bpg/proxmox` provider (`>= 0.66.0`), configured by the caller.
