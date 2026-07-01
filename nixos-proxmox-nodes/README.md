# nixos-proxmox-nodes

OpenTofu/Terraform module that provisions the Proxmox VMs backing NixOS nodes.
It downloads a generic cloud image (Debian by default), imports it as each VM's
disk, and injects an SSH key + static IP via cloud-init so the machine boots
reachable. It emits a `nixos_nodes` output shaped for
[`nixos-anywhere-install`](../nixos-anywhere-install), which then kexecs the
bootstrap distro and converts it to NixOS.

The bootstrap distro is disposable — `nixos-anywhere` repartitions the disk with
disko and installs NixOS over it. Mirrors `talos-proxmox-nodes` (image download +
cloud-init IP config), swapping the Talos ISO for an SSH-reachable cloud image.

## Requirements

- OpenTofu `>= 1.6.0`; provider `bpg/proxmox >= 0.66.0` (configured by the caller)
- A storage that supports importing a disk image (`import_from`)

## Key inputs

| Name | Description |
|---|---|
| `nodes` | `[{ name, target_pve, ip_address, cpu_*, memory_mb, disk_gb, storage_id? }]`. `name` must match a nixosConfigurations key. |
| `ssh_public_keys` | Authorized keys for the bootstrap user (include nixos-anywhere's install key). |
| `bootstrap_user` | cloud-init user (default `root`). |
| `bootstrap_image_url` / `bootstrap_image_file_name` | Cloud image to boot from. |
| `vm_storage_id` / `iso_storage_id` | VM disk datastore / image download datastore. |
| `default_cpu_cores`, `default_memory_mb`, `default_disk_gb`, … | Per-node resource defaults. |
| `network_gateway`, `network_subnet`, `network_bridge`, `nameserver` | Networking. |

## Outputs

- `vm_ids` — name => Proxmox VM ID.
- `nixos_nodes` — `[{ name, ip_address, vm_id }]` for `nixos-anywhere-install`.

## Example

```hcl
module "proxmox_nodes" {
  source = "git::https://github.com/kreativmonkey/terraform-module.git//nixos-proxmox-nodes?ref=v0.1.0"

  nodes = [
    { name = "nixos-docker1", target_pve = "white", ip_address = "192.168.10.61" },
  ]
  ssh_public_keys = [file("~/.ssh/id_ed25519.pub")]
  vm_storage_id   = "local-lvm"
  iso_storage_id  = "NFS-Storage"
}
```
