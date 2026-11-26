# nixos-hetzner

OpenTofu/Terraform module that creates **fresh** Hetzner Cloud servers to back
NixOS nodes. Each boots from a generic image (Debian) with your SSH keys
injected, so it is reachable for [`nixos-anywhere-install`](../nixos-anywhere-install)
to kexec and convert to NixOS. Emits a `nixos_nodes` output shaped for that
module. The Hetzner base image is disposable.

This is the Hetzner counterpart to `nixos-proxmox-nodes`: same `nixos_nodes`
contract, different machine source.

## Requirements

- OpenTofu `>= 1.6.0`; provider `hetznercloud/hcloud >= 1.45.0` (configured by the caller, i.e. `provider "hcloud" { token = ... }`)

## Key inputs

| Name | Description |
|---|---|
| `nodes` | `[{ name, server_type?, location?, labels? }]`. `name` must match a nixosConfigurations key. |
| `ssh_public_keys` | Keys uploaded to Hetzner + authorized on the server (include nixos-anywhere's install key). |
| `bootstrap_image` | Disposable first-boot image (default `debian-12`). |
| `default_server_type` / `default_location` | Defaults (e.g. `cx22` / `nbg1`). |
| `enable_ipv4` | Attach public IPv4 (default true); disable for IPv6-only. |

## Outputs

- `server_ids` — name => Hetzner server ID.
- `nixos_nodes` — `[{ name, ip_address, server_id }]` for `nixos-anywhere-install`.

## Example

```hcl
provider "hcloud" { token = var.hcloud_token }

module "hetzner_nodes" {
  source = "git::https://github.com/kreativmonkey/terraform-module.git//nixos-hetzner?ref=v0.1.0"

  nodes           = [{ name = "hetzner-vps1", server_type = "cx22", location = "nbg1" }]
  ssh_public_keys = [file("~/.ssh/id_ed25519.pub")]
}
```

> **Not for reinstalling an existing VPS.** This module creates *new* servers.
> Migrate your containers onto the fresh NixOS host, then decommission the old
> one. Running nixos-anywhere against a live server wipes its disk.
