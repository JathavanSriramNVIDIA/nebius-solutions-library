locals {
  platform_driver_presets = tomap({
    (local.platforms.gpu-h100-sxm) = try(
      var.platform_driver_presets["gpu-h100-sxm"],
      var.driver_presets["cuda12-8"]
    )
    (local.platforms.gpu-h200-sxm) = try(
      var.platform_driver_presets["gpu-h200-sxm"],
      var.driver_presets["cuda12-8"]
    )
    (local.platforms.gpu-b200-sxm) = try(
      var.platform_driver_presets["gpu-b200-sxm"],
      var.driver_presets["cuda12-8"]
    )
    (local.platforms.gpu-b200-sxm-a) = try(
      var.platform_driver_presets["gpu-b200-sxm-a"],
      var.driver_presets["cuda12-8"]
    )
    (local.platforms.gpu-b300-sxm) = try(
      var.platform_driver_presets["gpu-b300-sxm"],
      var.driver_presets["cuda13-0"],
      var.driver_presets["cuda12-8"]
    )
  })
}
