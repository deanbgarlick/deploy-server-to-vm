terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# Configure the Google Cloud provider
provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# Create a service account for the VM
resource "google_service_account" "vm_service_account" {
  account_id   = "fastapi-vm-runtime"
  display_name = "FastAPI VM Runtime Service Account"
  description  = "Service account for FastAPI server runtime operations"
}

# Grant minimal required permissions to the VM service account
resource "google_project_iam_member" "vm_logging_permissions" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.vm_service_account.email}"
}

resource "google_project_iam_member" "vm_monitoring_permissions" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.vm_service_account.email}"
}

resource "google_project_iam_member" "vm_tracer_permissions" {
  project = var.project_id
  role    = "roles/cloudtrace.agent"
  member  = "serviceAccount:${google_service_account.vm_service_account.email}"
}

# Create a VPC network
resource "google_compute_network" "vpc_network" {
  name                    = "fastapi-network"
  auto_create_subnetworks = "true"
}

# Reserve a static external IP address
resource "google_compute_address" "static_ip" {
  name = "fastapi-static-ip"
}

# Create firewall rules
resource "google_compute_firewall" "allow_http" {
  name    = "allow-http"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["8000"]  # Port for FastAPI server
  }

  source_ranges = var.allowed_ip_ranges
  target_tags   = ["fastapi-server"]
}

# Allow SSH access for management
resource "google_compute_firewall" "allow_ssh" {
  name    = "allow-ssh"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.allowed_ssh_ranges
  target_tags   = ["fastapi-server"]
}

# Create a compute instance
resource "google_compute_instance" "fastapi_instance" {
  name         = "fastapi-server"
  machine_type = "e2-micro"
  tags         = ["fastapi-server"]

  # Use the VM service account
  service_account {
    email  = google_service_account.vm_service_account.email
    scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring.write",
      "https://www.googleapis.com/auth/trace.append"
    ]
  }

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 10
    }
  }

  network_interface {
    network = google_compute_network.vpc_network.name
    access_config {
      nat_ip = google_compute_address.static_ip.address
    }
  }

  metadata_startup_script = templatefile("${path.module}/scripts/vm_init.sh", {
    requirements_content = file("${path.module}/requirements.txt")
    app_content = file("${path.module}/server/app.py")
  })

  # Allow stopping/starting the instance
  allow_stopping_for_update = true

  # Enable OS login
  metadata = {
    enable-oslogin = "TRUE"
  }
}

# Output the static IP
output "server_ip" {
  value = google_compute_address.static_ip.address
}

# Output the server URL
output "server_url" {
  value = "http://${google_compute_address.static_ip.address}:8000"
}

# Output service account emails
output "vm_service_account_email" {
  value = google_service_account.vm_service_account.email
  description = "Email address of the VM runtime service account"
}

# Output zone
output "zone" {
  value = var.zone
  description = "The zone where resources are deployed"
}
