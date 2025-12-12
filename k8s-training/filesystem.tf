resource "nebius_compute_v1_filesystem" "shared-filesystem" {
  count            = var.enable_filestore ? 1 : 0
  parent_id        = var.parent_id
  name             = join("-", ["filesystem-tf", local.release-suffix])
  type             = var.filestore_disk_type
  size_bytes       = provider::units::from_gib(var.filestore_disk_size)
  block_size_bytes = provider::units::from_kib(var.filestore_block_size)

  lifecycle {
    ignore_changes = [
      labels,
    ]
  }
}

data "nebius_compute_v1_filesystem" "shared-filesystem" {
  count = var.existing_sharedfs != null ? 1 : 0

  id = var.existing_sharedfs
}

locals {
  shared-filesystem = {
    id = try(
      one(nebius_compute_v1_filesystem.shared-filesystem).id,
      one(data.nebius_compute_v1_filesystem.shared-filesystem).id,
    )
    size_gibibytes = floor(provider::units::to_gib(try(
      one(nebius_compute_v1_filesystem.shared-filesystem).status.size_bytes,
      one(data.nebius_compute_v1_filesystem.shared-filesystem).status.size_bytes,
    )))
    mount_tag = local.const.filesystem.shared-filesystem
  }
}