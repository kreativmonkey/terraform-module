# Talos ISO on (shared) Proxmox storage. Downloaded once; reachable from every
# node because iso_storage_id points at shared storage (e.g. NFS).
resource "proxmox_download_file" "talos_iso" {
  content_type = "iso"
  datastore_id = var.iso_storage_id
  node_name    = local.iso_download_node

  url       = "https://factory.talos.dev/image/${var.talos_schematic_id}/${var.talos_version}/${var.image_platform}-${var.image_arch}.iso"
  file_name = "talos-${var.talos_version}-${var.image_platform}-${var.image_arch}.iso"
  overwrite = false
}
