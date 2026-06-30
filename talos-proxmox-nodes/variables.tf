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

variable "default_data_disks" {
  type = list(object({
    name         = string
    size_gb      = number
    mountpoint   = string
    datastore_id = optional(string)
  }))
  default     = []
  description = <<-EOT
    Named data disks created on every node, unless a node overrides them via
    node.data_disks. Each entry becomes one dedicated Proxmox disk plus a Talos
    partition mounted at `mountpoint` — e.g.
      [
        { name = "cnpg",     size_gb = 20, mountpoint = "/var/mnt/cnpg" },
        { name = "longhorn", size_gb = 80, mountpoint = "/var/lib/longhorn" },
      ]
    `datastore_id` falls back to the node's storage. Disks are attached in list
    order on scsi1, scsi2, … (the OS disk is scsi0).
  EOT

  validation {
    condition = (
      length(distinct([for d in var.default_data_disks : d.mountpoint])) == length(var.default_data_disks)
      && alltrue([for d in var.default_data_disks : startswith(d.mountpoint, "/")])
    )
    error_message = "default_data_disks mountpoints must be unique and absolute."
  }
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

    cpu_cores   = optional(number)
    cpu_sockets = optional(number)
    cpu_type    = optional(string)
    memory_mb   = optional(number)
    disk_gb     = optional(number)

    # Named data disks for this node. null => inherit var.default_data_disks;
    # [] => no data disks. Each becomes a Proxmox disk + a Talos mount at
    # `mountpoint`, attached in order on scsi1, scsi2, … (OS disk is scsi0).
    data_disks = optional(list(object({
      name         = string
      size_gb      = number
      mountpoint   = string
      datastore_id = optional(string)
    })))

    # Datastore for this node's main + data disks and the cloud-init drive.
    # Falls back to var.vm_storage_id. Use when a Proxmox host exposes a different
    # storage name (e.g. local_storage vs. the cluster-wide local-lvm).
    storage_id = optional(string)

    # Raw extra disks created on the VM but NOT mounted by Talos (passthrough /
    # manual use). Attached after the data disks.
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

  validation {
    condition = alltrue([
      for n in var.nodes : n.data_disks == null ? true : (
        length(distinct([for d in n.data_disks : d.mountpoint])) == length(n.data_disks)
        && alltrue([for d in n.data_disks : startswith(d.mountpoint, "/")])
      )
    ])
    error_message = "Each node's data_disks must have unique, absolute mountpoints."
  }
}
