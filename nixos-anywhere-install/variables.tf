# Platform-agnostic NixOS installer. This module does NOT create machines — it
# runs nixos-anywhere against hosts that are already reachable over SSH (any
# booted Linux: a Debian cloud image on Proxmox, a fresh Hetzner server, ...),
# kexecs into the NixOS installer, partitions with disko, and installs the
# nixosConfiguration built from `flake`. Analogous to the talos-cluster module.

variable "flake" {
  type        = string
  description = <<-EOT
    Flake reference containing the nixosConfigurations, e.g. an absolute path
    ("/…/homelab-infrastructure/nixos") or "path:/…/nixos". The module builds
    <flake>#nixosConfigurations.<hostname>.config.system.build.{toplevel,diskoScript}.
    Note: with a git-tracked flake, only committed (or staged) files are visible
    to `nix build` — commit/`git add` host files before applying.
  EOT
}

variable "hosts" {
  description = <<-EOT
    Hosts to install NixOS on. `hostname` MUST match a key in the flake's
    nixosConfigurations. `target_host` is the reachable IP/DNS of the booted
    bootstrap system. `instance_id` ties the install to the underlying machine
    (e.g. the Proxmox VM id or Hetzner server id) so replacing the machine
    triggers a reinstall; keep it stable otherwise.
  EOT
  type = list(object({
    hostname     = string
    target_host  = string
    instance_id  = string
    install_user = optional(string, "root")
    target_user  = optional(string, "root")
  }))

  validation {
    condition     = length(distinct([for h in var.hosts : h.hostname])) == length(var.hosts)
    error_message = "host.hostname values must be unique (and match nixosConfigurations keys)."
  }
}

variable "install_ssh_private_key" {
  type        = string
  default     = null
  sensitive   = true
  description = "Private key content for the initial (install-phase) SSH connection. Its public half must be authorized on the bootstrap system by the node module. If null, the local SSH agent is used."
}

variable "build_on_remote" {
  type        = bool
  default     = false
  description = "Build the system closure on the target instead of locally. Handy when the machine running OpenTofu is not x86_64-linux."
}

variable "extra_environment" {
  type        = map(string)
  default     = {}
  description = "Extra environment variables passed through to nixos-anywhere."
}

variable "nixos_anywhere_ref" {
  type        = string
  default     = "main"
  description = "Git ref of nix-community/nixos-anywhere to source the all-in-one module from. Pin for reproducibility."
}
