# Hetzner Cloud server provisioning for NixOS nodes. Creates fresh servers booted
# from a generic image (Debian) with an SSH key injected via cloud-init, so each
# is reachable for the nixos-anywhere-install module to kexec and convert to
# NixOS. Analogous to nixos-proxmox-nodes, for Hetzner Cloud.
#
# The hcloud provider (token) is configured by the caller.

variable "ssh_public_keys" {
  type        = list(string)
  description = "SSH public keys authorized on the servers (must include the public half of the key nixos-anywhere uses to connect)."

  validation {
    condition     = length(var.ssh_public_keys) > 0
    error_message = "Provide at least one SSH public key; Hetzner servers created without one only allow root-password login by email."
  }
}

variable "ssh_key_name_prefix" {
  type        = string
  default     = "nixos"
  description = "Prefix for the hcloud_ssh_key resources uploaded from ssh_public_keys."
}

variable "bootstrap_image" {
  type        = string
  default     = "debian-12"
  description = "Hetzner image the server first boots from (disposable; nixos-anywhere kexecs off it). Any recent Debian/Ubuntu works."
}

variable "default_server_type" {
  type        = string
  default     = "cx22"
  description = "Default Hetzner server type (e.g. cx22, cpx21). Override per node."
}

variable "default_location" {
  type        = string
  default     = "nbg1"
  description = "Default Hetzner location/datacenter (e.g. nbg1, fsn1, hel1)."
}

variable "enable_ipv4" {
  type        = bool
  default     = true
  description = "Attach a public IPv4. Disable to run IPv6-only (cheaper); nixos-anywhere must then reach the server over IPv6."
}

variable "nodes" {
  description = "List of Hetzner servers to create. name MUST match a flake nixosConfigurations key."
  type = list(object({
    name        = string
    server_type = optional(string)
    location    = optional(string)
    labels      = optional(map(string), {})
  }))

  validation {
    condition     = length(distinct([for n in var.nodes : n.name])) == length(var.nodes)
    error_message = "node.name values must be unique (and match nixosConfigurations keys)."
  }
}
