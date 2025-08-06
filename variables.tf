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