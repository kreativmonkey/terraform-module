terraform {
  required_version = ">= 1.6.0"

  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = ">= 0.12.0, < 0.13.0"
    }
  }
}
