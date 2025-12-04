locals {
  gres_by_platforms = tomap({
    (local.platforms.gpu-h100-sxm)   = "nvidia_h100_80gb_hbm3"
    (local.platforms.gpu-h200-sxm)   = "nvidia_h200"
    (local.platforms.gpu-b200-sxm)   = "nvidia_b200"
    (local.platforms.gpu-b200-sxm-a) = "nvidia_b200"
    (local.platforms.gpu-b300-sxm)   = "nvidia_b300_sxm6_ac"
  })
}
