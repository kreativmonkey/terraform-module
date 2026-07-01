# Proxmox VM provisioning for NixOS nodes. This module only creates the machines
# and boots them into a generic Linux cloud image (Debian by default) with an
# SSH key injected via cloud-init. That booted system is the reachable bootstrap
# target that the nixos-anywhere-install module then kexecs and converts to
# NixOS. Analogous to talos-proxmox-nodes.

# ---------------------------------------------------------------------------
# Storage
# ---------------------------------------------------------------------------
variable "vm_storage_id" {
  type    = string
  default = "local-lvm"
}

variable "iso_storage_id" {
  type        = string
  default     = "NFS-Storage"
  description = "Datastore for the downloaded bootstrap cloud image. Use shared storage so a single download is reachable from every Proxmox node."
}

# ---------------------------------------------------------------------------
# Bootstrap image (any cloud-init-capable Linux; nixos-anywhere kexecs from it)
# ---------------------------------------------------------------------------
variable "bootstrap_image_url" {
  type        = string
  default     = "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2"
  description = "URL of the bootstrap cloud image imported as the VM's disk."
}

variable "bootstrap_image_file_name" {
  type        = string
  default     = "debian-12-genericcloud-amd64.img"
  description = "Local file name for the downloaded image. bpg requires an .img/.iso extension for the iso content type."
}

# ---------------------------------------------------------------------------
# Bootstrap SSH access (public half of nixos-anywhere-install's install key)
# ---------------------------------------------------------------------------
variable "ssh_public_keys" {
  type        = list(string)
  description = "SSH public keys authorized for the bootstrap user (must include the public half of the key nixos-anywhere uses to connect)."
}

variable "bootstrap_user" {
  type        = string
  default     = "root"
  description = "cloud-init user the SSH keys are authorized for. Use root so nixos-anywhere connects as root by default."
}

# ---------------------------------------------------------------------------
# Per-node resource defaults (overridable per node)
# ---------------------------------------------------------------------------
variable "default_cpu_cores" {
  type    = number
  default = 2
}

variable "default_cpu_sockets" {
  type    = number
  default = 1
}

variable "default_cpu_type" {
  type    = string
  default = "x86-64-v2-AES"
}

variable "default_memory_mb" {
  type    = number
  default = 4096
}

variable "default_disk_gb" {
  type    = number
  default = 30
}

# ---------------------------------------------------------------------------
# Network
# ---------------------------------------------------------------------------
variable "network_gateway" {
  type    = string
  default = "192.168.10.1"
}

variable "network_subnet" {
  type    = number
  default = 24
}

variable "network_bridge" {
  type    = string
  default = "vmbr0"
}

variable "nameserver" {
  type    = string
  default = "192.168.10.1"
}

# ---------------------------------------------------------------------------
# Nodes
# ---------------------------------------------------------------------------
variable "nodes" {
  description = "List of nodes to provision as Proxmox VMs. name MUST match a flake nixosConfigurations key."
  type = list(object({
    name       = string
    target_pve = string
    ip_address = string

    cpu_cores   = optional(number)
    cpu_sockets = optional(number)
    cpu_type    = optional(string)
    memory_mb   = optional(number)
    disk_gb     = optional(number)

    # Per-node datastore override (falls back to var.vm_storage_id).
    storage_id = optional(string)
  }))

  validation {
    condition     = length(distinct([for n in var.nodes : n.name])) == length(var.nodes)
    error_message = "node.name values must be unique (and match nixosConfigurations keys)."
  }
}
