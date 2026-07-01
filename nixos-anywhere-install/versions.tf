terraform {
  required_version = ">= 1.6.0"

  # No providers configured here directly: the nix-community/nixos-anywhere
  # all-in-one child module pulls in the providers it needs (external, null,
  # tls). This wrapper only fans that module out per host.
}
