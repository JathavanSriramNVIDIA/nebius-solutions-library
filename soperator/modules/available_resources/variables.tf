variable "driver_presets" {
  description = "Map of named GPU driver presets to the driver string expected by Nebius MK8s."
  type        = map(string)
  default     = {}
}

variable "platform_driver_presets" {
  description = "Optional per-platform override for GPU driver presets. Keys are platform IDs (e.g., gpu-h100-sxm); values are driver presets (e.g., cuda13.0)."
  type        = map(string)
  default     = {}
}
