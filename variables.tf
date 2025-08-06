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

variable "deployment_mode" {
  description = "Either 'local_test' or 'github_public'"
  type        = string
  default     = "local_test"
  validation {
    condition     = contains(["local_test", "github_public"], var.deployment_mode)
    error_message = "deployment_mode must be either 'local_test' or 'github_public'"
  }
}

variable "github_repo_url" {
  description = "Public GitHub repository URL (only used when deployment_mode = 'github_public')"
  type        = string
  default     = ""
}

variable "github_branch" {
  description = "GitHub branch to deploy (only used when deployment_mode = 'github_public')"
  type        = string
  default     = "main"
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