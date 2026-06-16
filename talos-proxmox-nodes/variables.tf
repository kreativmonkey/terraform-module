# Proxmox VM provisioning for Talos nodes. This module only creates the machines
# and downloads the Talos ISO; the Talos cluster itself is configured by the
# (platform-agnostic) talos-cluster module.

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
  description = "Datastore for the downloaded Talos ISO. Use shared storage so a single download is reachable from every Proxmox node."
}

# ---------------------------------------------------------------------------
# Talos image (used to build the ISO URL)
# ---------------------------------------------------------------------------
variable "talos_version" {
  type    = string
  default = "v1.13.2"
}

variable "talos_schematic_id" {
  type        = string
  description = "Talos Image Factory schematic ID."
}

variable "image_platform" {
  type    = string
  default = "nocloud"
}

variable "image_arch" {
  type    = string
  default = "amd64"
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
  default = 20
}

variable "default_longhorn_disk_gb" {
  type        = number
  default     = 50
  description = "Default Longhorn data-disk size. Set a node's longhorn_disk_gb to 0 to deploy it without a Longhorn disk."
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

variable "vm_description" {
  type        = string
  default     = null
  description = "Description set on the VMs. Defaults to the module's bundled talos-desc.html when unset."
}

# ---------------------------------------------------------------------------
# Nodes
# ---------------------------------------------------------------------------
variable "nodes" {
  description = "List of nodes to provision as Proxmox VMs. role/allow_scheduling are accepted but only consumed by the talos-cluster module."
  type = list(object({
    name       = string
    target_pve = string
    ip_address = string

    role             = optional(string, "controlplane")
    allow_scheduling = optional(bool)

    cpu_cores        = optional(number)
    cpu_sockets      = optional(number)
    cpu_type         = optional(string)
    memory_mb        = optional(number)
    disk_gb          = optional(number)
    longhorn_disk_gb = optional(number)

    extra_disks = optional(list(object({
      size         = number
      datastore_id = optional(string)
      interface    = optional(string)
    })), [])
  }))

  validation {
    condition     = length(distinct([for n in var.nodes : n.name])) == length(var.nodes)
    error_message = "node.name values must be unique."
  }
}
