# nixos-anywhere-install

Platform-agnostic OpenTofu/Terraform module that installs NixOS onto machines
that are **already reachable over SSH** (booted into any Linux). It wraps the
official [`nix-community/nixos-anywhere`](https://github.com/nix-community/nixos-anywhere)
`terraform/all-in-one` module and fans it out per host.

Mirrors the split used by the Talos modules: the *node* modules
([`nixos-proxmox-nodes`](../nixos-proxmox-nodes),
[`nixos-hetzner`](../nixos-hetzner)) create machines and expose a `nixos_nodes`
output; this module turns those machines into NixOS. It does **not** create any
infrastructure.

## What it does per host

`kexec` into the NixOS installer → `disko` partitioning → install the
`nixosConfigurations.<hostname>` closure → reboot. Re-runs automatically when a
host's `instance_id` changes (machine replaced).

## Requirements

- OpenTofu `>= 1.6.0`
- `nix` on the machine running OpenTofu (with flakes enabled), or set
  `build_on_remote = true`
- A flake exposing `nixosConfigurations.<hostname>` for every host, each with a
  `disko` disk layout (provides `config.system.build.diskoScript`)

## Inputs

| Name | Description |
|---|---|
| `flake` | Flake ref holding the nixosConfigurations (absolute path or `path:…`). |
| `hosts` | `[{ hostname, target_host, instance_id, install_user?, target_user? }]`. `hostname` must match a nixosConfigurations key. |
| `install_ssh_private_key` | Private key for the install-phase SSH connection (public half authorized by the node module). |
| `build_on_remote` | Build the closure on the target (use when the TF host is not x86_64-linux). |
| `nixos_anywhere_ref` | Git ref of nixos-anywhere to pin. |

## Outputs

- `installed_hosts` — hostname => target_host.
- `result` — raw per-host results; depend on it to gate day-2 (colmena) steps.

## Example

```hcl
module "install" {
  source = "git::https://github.com/kreativmonkey/terraform-module.git//nixos-anywhere-install?ref=v0.1.0"

  flake = "${path.module}/../.." # dir containing flake.nix

  hosts = concat(
    [for n in module.proxmox_nodes.nixos_nodes : {
      hostname = n.name, target_host = n.ip_address, instance_id = tostring(n.vm_id)
    }],
    [for n in module.hetzner_nodes.nixos_nodes : {
      hostname = n.name, target_host = n.ip_address, instance_id = tostring(n.server_id)
    }],
  )

  install_ssh_private_key = var.bootstrap_ssh_private_key
}
```

> **Flake + git:** with a git-tracked flake, `nix build` only sees committed (or
> staged) files. `git add` the host/disko files before `apply`.
