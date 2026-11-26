# talos-proxmox-nodes/

## Purpose

Proxmox node source for Talos: creates the VMs that back Talos nodes and downloads
the Talos ISO. Emits a `talos_nodes` output shaped for `../talos-cluster`'s `nodes` input.

## Ownership

- Owns Proxmox VM provisioning + Talos image. Cluster config is `../talos-cluster`.

## Local Contracts

- Provider: `bpg/proxmox` only.
- Files: `vms.tf`, `images.tf`, `locals.tf`, `variables.tf`, `outputs.tf`, `versions.tf`.
- Needs a Talos Image Factory schematic ID for required system extensions.
- Full usage + variables: `README.md`. Keep it in sync with `variables.tf`/`outputs.tf`.

## Verification

- `tofu fmt -check`, `tofu validate`.
