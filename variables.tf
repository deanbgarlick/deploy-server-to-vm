variable "project_id" {
  description = "The ID of the GCP project"
  type        = string
}

variable "region" {
  description = "The region to deploy resources to"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "The zone to deploy resources to"
  type        = string
  default     = "us-central1-a"
}

variable "machine_type" {
  description = "The machine type to use for the VM (e.g., e2-micro, e2-medium)"
  type        = string
  default     = "e2-medium"
}

variable "disk_size" {
  description = "Size of the boot disk in GB"
  type        = number
  default     = 10
}

variable "disk_image" {
  description = "The disk image to use for the boot disk"
  type        = string
  default     = "ubuntu-minimal-2204-lts"
}

variable "allowed_ip_ranges" {
  description = "List of IP ranges that can access the FastAPI server (CIDR notation)"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Allow all by default, but consider restricting this
}

variable "allowed_ssh_ranges" {
  description = "List of IP ranges that can SSH to the server (CIDR notation)"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Allow all by default, but consider restricting this
} 