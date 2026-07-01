# talos-cluster/

## Purpose

Platform-agnostic module: machine secrets, per-node control-plane/worker config,
bootstrap, kubeconfig, and cluster health. Configures Talos on nodes already booted
into maintenance mode at known IPs. Does NOT create machines.

## Ownership

- Owns Talos config + bootstrap contract. Node creation is a separate module (`../talos-proxmox-nodes` or any node source).

## Local Contracts

- Provider: `siderolabs/talos` only.
- Files: `cluster.tf`, `machine.tf`, `locals.tf`, `variables.tf`, `outputs.tf`, `versions.tf`.
- `nodes` input shape matches `talos-proxmox-nodes` `talos_nodes` output.
- Full usage + variables: `README.md`. Keep it in sync with `variables.tf`/`outputs.tf`.

## Verification

- `tofu fmt -check`, `tofu validate`.
