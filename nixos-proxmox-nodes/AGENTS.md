# nixos-proxmox-nodes/

## Purpose

Proxmox node source for NixOS: creates VMs, imports a generic cloud image
(Debian) as the disk, and injects SSH key + static IP via cloud-init so the VM
boots reachable. Emits `nixos_nodes` (name, ip_address, vm_id) for
`../nixos-anywhere-install`. The bootstrap distro is disposable. Analogous to
`../talos-proxmox-nodes`.

## Ownership

- Owns Proxmox VM provisioning + bootstrap image. NixOS install is `../nixos-anywhere-install`.

## Local Contracts

- Provider: `bpg/proxmox` only.
- Files: `vms.tf`, `images.tf`, `locals.tf`, `variables.tf`, `outputs.tf`, `versions.tf`.
- `ssh_public_keys` MUST include the public half of the key nixos-anywhere connects with.
- `node.name` MUST match a flake `nixosConfigurations` key. `vm_id` → install `instance_id`.
- Full usage: `README.md`. Keep in sync with `variables.tf`/`outputs.tf`.

## Verification

- `tofu fmt -check`, `tofu validate`.
