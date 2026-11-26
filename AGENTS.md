# terraform-module — Repo DOX Rail

## Purpose

Reusable OpenTofu/Terraform modules for the homelab. Two module families, each
split by responsibility (machine-source vs. OS-config) so pieces combine or swap
independently:

- **Talos** — Talos Linux Kubernetes cluster on Proxmox. Consumed by
  `../homelab-infrastructure/talos/envs/homelab-kube`.
- **NixOS** — declarative NixOS hosts on Proxmox and Hetzner Cloud (podman
  containers, colmena day-2). Consumed by
  `../homelab-infrastructure/nixos/envs/homelab-nixos`.

Consumed via pinned git `?ref=` tags (or local path during development).

## Ownership

- This repo owns the modules below and their public input/output contracts.
- Concrete cluster/host wiring and secrets live in the consumer repo, not here.

## Local Contracts

### Talos family
- `talos-cluster` — configures Talos + bootstraps Kubernetes on already-reachable nodes. **Platform-agnostic** (provider `siderolabs/talos`). Does NOT create machines.
- `talos-proxmox-nodes` — provisions Proxmox VMs + downloads Talos ISO (provider `bpg/proxmox`); emits `talos_nodes` shaped for `talos-cluster`'s `nodes` input.
- Requirements: providers `bpg/proxmox >= 0.66.0`, `siderolabs/talos >= 0.6.0`; a Talos Image Factory schematic ID.

### NixOS family
- `nixos-anywhere-install` — installs NixOS on already-reachable SSH hosts via nixos-anywhere (kexec → disko → install). **Platform-agnostic** (wraps `nix-community/nixos-anywhere//terraform/all-in-one`). Does NOT create machines.
- `nixos-proxmox-nodes` — Proxmox VMs booted from a disposable cloud image + cloud-init SSH (provider `bpg/proxmox`); emits `nixos_nodes` (name, ip_address, vm_id).
- `nixos-hetzner` — fresh Hetzner Cloud servers (provider `hetznercloud/hcloud >= 1.45.0`); emits `nixos_nodes` (name, ip_address, server_id). Same `nixos_nodes` contract as the Proxmox source.
- `node.name` / `hostname` MUST match a flake `nixosConfigurations` key; the machine's id becomes the install `instance_id`.

### Shared
- Requirements: OpenTofu `>= 1.6.0`; providers configured by the caller.
- **Publish by tag**: consumers pin `?ref=vX.Y.Z`. Treat input/output changes as versioned API — bump tags, do not break pinned refs.
- Strictly `tofu fmt`. Document inputs/outputs in each module README.

## Verification

- `tofu fmt -check` and `tofu validate` per module.

## Child DOX Index

- `talos-cluster/AGENTS.md` — Talos config + cluster bootstrap module.
- `talos-proxmox-nodes/AGENTS.md` — Proxmox VM node-source module (Talos).
- `nixos-anywhere-install/AGENTS.md` — platform-agnostic NixOS installer.
- `nixos-proxmox-nodes/AGENTS.md` — Proxmox VM node-source module (NixOS).
- `nixos-hetzner/AGENTS.md` — Hetzner Cloud node-source module (NixOS).

---

# DOX framework

- DOX is highly performant AGENTS.md hierarchy installed to this repository
- Agent must follow DOX instructions across any edits

## Read Before Editing

1. Read the root (workspace) AGENTS.md and this repo AGENTS.md
2. Identify every file/folder you expect to touch
3. Read every AGENTS.md along the route to each target; nearest doc is the local contract
4. If docs conflict, the closer doc controls local details, but no child may weaken DOX

Do not rely on memory. Re-read the DOX chain in the current session before editing.

## Update After Editing

Every meaningful change requires a DOX pass. Update the closest owning AGENTS.md when a change affects purpose, scope, ownership, durable structure, contracts, workflows, inputs/outputs, constraints, artifacts, or index contents. Remove stale text immediately.

## Style

Concise, current, operational. Broad rules in parents, concrete details in children. Direct bullets, explicit names. No needless duplication. Delete stale notes.

## Caveman

ACTIVE EVERY RESPONSE (off only: "stop caveman" / "normal mode"). Drop articles, filler, pleasantries, hedging. Fragments OK. Keep technical terms, code, CLI commands, commit-type keywords, and exact error strings verbatim. No self-reference. Pattern: `[thing] [action] [reason]. [next step].` Drop caveman for security warnings, irreversible-action confirmations, or ambiguous multi-step sequences; resume after.

Commit subjects: `<type>(<scope>): <imperative summary>`, ≤50 chars (cap 72), no trailing period, no AI attribution.

## Closeout

1. Re-check changed paths against the DOX chain
2. Update nearest owning docs and affected parents/children
3. Refresh affected Child DOX Index
4. Remove stale text; run verification when relevant
5. Report docs intentionally left unchanged and why
