locals {
  gres_by_platforms = tomap({
    (local.platforms.gpu-h100-sxm)   = "nvidia_h100_80gb_hbm3"
    (local.platforms.gpu-h200-sxm)   = "nvidia_h200"
    (local.platforms.gpu-b200-sxm)   = "nvidia_b200"
    (local.platforms.gpu-b200-sxm-a) = "nvidia_b200"
    (local.platforms.gpu-b300-sxm)   = "nvidia_b300_sxm6_ac"
  })

  gres_config_by_platforms = tomap({
    (local.platforms.gpu-h100-sxm) = [
      "TODO",
    ]
    (local.platforms.gpu-h200-sxm) = [
      "AutoDetect=off Name=gpu Type=nvidia_h200 File=/dev/nvidia0 Cores=32-63 Links=1,1,1,1,1,1,1,-1 Flags=nvidia_gpu_env",
      "AutoDetect=off Name=gpu Type=nvidia_h200 File=/dev/nvidia1 Cores=32-63 Links=1,1,1,1,1,1,-1,1 Flags=nvidia_gpu_env",
      "AutoDetect=off Name=gpu Type=nvidia_h200 File=/dev/nvidia2 Cores=32-63 Links=1,1,1,1,1,-1,1,1 Flags=nvidia_gpu_env",
      "AutoDetect=off Name=gpu Type=nvidia_h200 File=/dev/nvidia3 Cores=32-63 Links=1,1,1,1,-1,1,1,1 Flags=nvidia_gpu_env",
      "AutoDetect=off Name=gpu Type=nvidia_h200 File=/dev/nvidia4 Cores=0-31 Links=1,1,1,-1,1,1,1,1 Flags=nvidia_gpu_env",
      "AutoDetect=off Name=gpu Type=nvidia_h200 File=/dev/nvidia5 Cores=0-31 Links=1,1,-1,1,1,1,1,1 Flags=nvidia_gpu_env",
      "AutoDetect=off Name=gpu Type=nvidia_h200 File=/dev/nvidia6 Cores=0-31 Links=1,-1,1,1,1,1,1,1 Flags=nvidia_gpu_env",
      "AutoDetect=off Name=gpu Type=nvidia_h200 File=/dev/nvidia7 Cores=0-31 Links=-1,1,1,1,1,1,1,1 Flags=nvidia_gpu_env",
    ]
    (local.platforms.gpu-b200-sxm) = [
      "TODO",
    ]
    (local.platforms.gpu-b200-sxm-a) = [
      "TODO",
    ]
    (local.platforms.gpu-b300-sxm) = [
      "TODO",
    ]
  })
}
