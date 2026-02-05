locals {
  # Resolve per-platform driver presets with fallbacks so we can reuse them across modules.
  platform_driver_presets_resolved = tomap({
    "gpu-h100-sxm" = try(
      var.platform_driver_presets["gpu-h100-sxm"],
      var.driver_presets["cuda12-8"]
    )
    "gpu-h200-sxm" = try(
      var.platform_driver_presets["gpu-h200-sxm"],
      var.driver_presets["cuda12-8"]
    )
    "gpu-b200-sxm" = try(
      var.platform_driver_presets["gpu-b200-sxm"],
      var.driver_presets["cuda12-8"]
    )
    "gpu-b200-sxm-a" = try(
      var.platform_driver_presets["gpu-b200-sxm-a"],
      var.driver_presets["cuda12-8"]
    )
    "gpu-b300-sxm" = try(
      var.platform_driver_presets["gpu-b300-sxm"],
      var.driver_presets["cuda13-0"],
      var.driver_presets["cuda12-8"]
    )
  })

  worker_platforms_preinstalled = distinct([
    for worker in var.slurm_nodeset_workers : worker.resource.platform
    if var.use_preinstalled_gpu_drivers
  ])
}

resource "terraform_data" "check_driver_presets" {
  lifecycle {
    precondition {
      condition = length(setsubtract(
        toset(local.worker_platforms_preinstalled),
        toset(keys(local.platform_driver_presets_resolved))
      )) == 0
      error_message = format(
        "Missing driver preset for platform(s): %s",
        join(
          ", ",
          setsubtract(
            toset(local.worker_platforms_preinstalled),
            toset(keys(local.platform_driver_presets_resolved))
          )
        )
      )
    }
  }
}
