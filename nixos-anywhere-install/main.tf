locals {
  hosts_map = { for h in var.hosts : h.hostname => h }
}

# Fan the upstream all-in-one module out once per host. It handles the full
# kexec -> disko -> install -> reboot lifecycle and re-runs when instance_id
# changes (i.e. the backing machine was replaced).
module "install" {
  source   = "github.com/nix-community/nixos-anywhere//terraform/all-in-one?ref=${var.nixos_anywhere_ref}"
  for_each = local.hosts_map

  nixos_system_attr      = "${var.flake}#nixosConfigurations.${each.value.hostname}.config.system.build.toplevel"
  nixos_partitioner_attr = "${var.flake}#nixosConfigurations.${each.value.hostname}.config.system.build.diskoScript"

  target_host  = each.value.target_host
  install_user = each.value.install_user
  target_user  = each.value.target_user

  instance_id     = each.value.instance_id
  install_ssh_key = var.install_ssh_private_key
  build_on_remote = var.build_on_remote

  extra_environment = var.extra_environment
}
