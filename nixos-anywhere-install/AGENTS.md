# nixos-anywhere-install/

## Purpose

Platform-agnostic NixOS installer: runs nixos-anywhere (kexec → disko → install
→ reboot) against already-reachable SSH hosts. Wraps `nix-community/nixos-anywhere`
`//terraform/all-in-one`, fanned out per host. Does NOT create machines.
Analogous to `../talos-cluster`.

## Ownership

- Owns the NixOS install contract. Machine creation is `../nixos-proxmox-nodes` / `../nixos-hetzner`.

## Local Contracts

- No provider configured here; the child all-in-one module pulls external/null/tls.
- Files: `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`.
- `hosts[].hostname` MUST match a flake `nixosConfigurations` key; that config MUST include a disko layout (`config.system.build.diskoScript`).
- `instance_id` ties an install to its machine → reinstall on replacement.
- Flake is built locally by `nix`; git-tracked flakes only see committed/staged files.
- Full usage: `README.md`. Keep in sync with `variables.tf`/`outputs.tf`.

## Verification

- `tofu fmt -check`, `tofu validate` (needs network to fetch the child module).
