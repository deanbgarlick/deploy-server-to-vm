project_id = "example-sever-deployment"
region     = "us-central1"
zone       = "us-central1-a"
allowed_ip_ranges = ["0.0.0.0/0"]
allowed_ssh_ranges = ["0.0.0.0/0"]
machine_type = "e2-medium"
disk_size = 10
disk_image = "ubuntu-minimal-2204-lts" 