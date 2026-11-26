# nixos-hetzner/

## Purpose

Hetzner Cloud node source for NixOS: creates fresh servers booted from a generic
image (Debian) with SSH keys injected, reachable for `../nixos-anywhere-install`.
Emits `nixos_nodes` (name, ip_address, server_id). Hetzner counterpart to
`../nixos-proxmox-nodes` — same output contract, different machine source.

## Ownership

- Owns Hetzner Cloud server provisioning. NixOS install is `../nixos-anywhere-install`.

## Local Contracts

- Provider: `hetznercloud/hcloud` only (token configured by the caller).
- Files: `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`.
- Creates NEW servers only; never point install at a live VPS (disk wipe). Migrate then decommission.
- `node.name` MUST match a flake `nixosConfigurations` key. `server_id` → install `instance_id`.
- `image`/`ssh_keys` under `ignore_changes` so base drift doesn't recreate installed nodes.
- Full usage: `README.md`. Keep in sync with `variables.tf`/`outputs.tf`.

## Verification

- `tofu fmt -check`, `tofu validate`.
