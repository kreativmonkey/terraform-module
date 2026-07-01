# Bootstrap cloud image on (shared) Proxmox storage. Downloaded once; imported as
# each VM's disk. nixos-anywhere kexecs from this into the NixOS installer, so the
# distro only has to boot with cloud-init + SSH — it is thrown away on install.
resource "proxmox_download_file" "bootstrap" {
  content_type = "iso"
  datastore_id = var.iso_storage_id
  node_name    = local.iso_download_node

  url       = var.bootstrap_image_url
  file_name = var.bootstrap_image_file_name
  overwrite = false
}
