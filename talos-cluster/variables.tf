# Platform-agnostic Talos cluster configuration. This module does NOT create any
# machines — it configures Talos on nodes that are already reachable (in
# maintenance mode) at the given IPs, regardless of platform (Proxmox, bare
# metal, vSphere, ...).

# ---------------------------------------------------------------------------
# Cluster identity
# ---------------------------------------------------------------------------
variable "cluster_name" {
  type        = string
  description = "Talos/Kubernetes cluster name."
}

variable "cluster_endpoint_ip" {
  type        = string
  description = "Control-plane VIP advertised on the control-plane interfaces; used as the Kubernetes API endpoint."
}

# ---------------------------------------------------------------------------
# Talos image / installer
# ---------------------------------------------------------------------------
variable "talos_version" {
  type    = string
  default = "v1.13.2"
}

variable "talos_schematic_id" {
  type        = string
  description = "Talos Image Factory schematic ID (defines bundled system extensions)."
}

variable "image_platform" {
  type        = string
  default     = "nocloud"
  description = "Image Factory platform; used to build the installer image reference (<platform>-installer)."
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

variable "kubelet_valid_subnet" {
  type        = string
  default     = "192.168.10.0/24"
  description = "CIDR the kubelet must register from (LAN). Keeps node IPs off any mesh range (e.g. Netbird) so metrics-server/exec/port-forward work."
}

variable "etcd_advertised_subnets" {
  type        = list(string)
  default     = null
  description = <<-EOT
    etcd advertisedSubnets. Defaults to [kubelet_valid_subnet]. Set explicitly to
    pin etcd's advertised address onto the LAN and exclude mesh ranges, e.g.
    ["192.168.10.0/24", "!100.64.0.0/10"] to keep etcd off the Netbird range.
  EOT
}

# ---------------------------------------------------------------------------
# Nodes
# ---------------------------------------------------------------------------
variable "nodes" {
  description = <<-EOT
    Nodes to join to the cluster. `role` selects the Talos machine type:
      - "controlplane": joins the control plane. `allow_scheduling` controls
        whether it also runs regular workloads (manager vs. manager+worker).
      - "worker": pure worker.
    `data_disks` is a list of { device, mountpoint } partitions to mount on the
    node (typically produced by the talos-proxmox-nodes module's talos_nodes
    output, which resolves each named disk to its guest device).
  EOT

  type = list(object({
    name             = string
    ip_address       = string
    role             = optional(string, "controlplane")
    allow_scheduling = optional(bool)
    data_disks = optional(list(object({
      device     = string
      mountpoint = string
    })), [])
  }))

  validation {
    condition     = alltrue([for n in var.nodes : contains(["controlplane", "worker"], n.role)])
    error_message = "Each node.role must be either \"controlplane\" or \"worker\"."
  }

  validation {
    condition     = length([for n in var.nodes : n if n.role == "controlplane"]) >= 1
    error_message = "At least one node must have role = \"controlplane\"."
  }

  validation {
    condition     = alltrue([for n in var.nodes : n.allow_scheduling == null if n.role == "worker"])
    error_message = "allow_scheduling only applies to controlplane nodes; leave it unset for workers (workers always schedule)."
  }

  validation {
    condition     = length(distinct([for n in var.nodes : n.name])) == length(var.nodes)
    error_message = "node.name values must be unique."
  }
}

variable "extra_config_patches" {
  description = "Additional Talos config patches (as objects) applied to every node."
  type        = list(any)
  default     = []
}
