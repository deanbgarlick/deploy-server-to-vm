#!/bin/bash

# Exit on any error
set -e

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to monitor VM startup script logs
monitor_startup_script() {
    local instance_name="fastapi-server"
    local zone=$(terraform output -raw zone)
    local max_attempts=30
    local attempt=1
    local wait_time=10

    log_message "Monitoring VM startup script logs..."
    log_message "This may take a few minutes. Waiting for VM to be ready..."
    
    while [ $attempt -le $max_attempts ]; do
        if gcloud compute instances get-serial-port-output "$instance_name" \
            --zone="$zone" 2>/dev/null | grep "Server setup completed successfully!" >/dev/null; then
            log_message "VM startup script completed successfully!"
            return 0
        fi
        
        # Check if there are any errors in the startup script
        if gcloud compute instances get-serial-port-output "$instance_name" \
            --zone="$zone" 2>/dev/null | grep "Error: Failed to" >/dev/null; then
            log_message "Error detected in startup script. Full startup logs:"
            gcloud compute instances get-serial-port-output "$instance_name" --zone="$zone"
            return 1
        fi
        
        log_message "Still waiting for startup script to complete... (attempt $attempt/$max_attempts)"
        sleep $wait_time
        attempt=$((attempt + 1))
    done

    log_message "Timeout waiting for startup script to complete. Last few lines of startup logs:"
    gcloud compute instances get-serial-port-output "$instance_name" --zone="$zone" | tail -n 20
    return 1
}

# Check if terraform is installed
if ! command -v terraform &> /dev/null; then
    log_message "Error: terraform is not installed. Please install it first (e.g., 'brew install terraform' on Mac)"
    exit 1
fi

# Check if the service account key exists
KEY_FILE="secrets/terraform-deployer-sa.key"
if [ ! -f "$KEY_FILE" ]; then
    log_message "Error: Service account key not found at $KEY_FILE"
    log_message "Please run setup_deployer_permissions.sh first"
    exit 1
fi

# Export the credentials
log_message "Setting up authentication..."
export GOOGLE_APPLICATION_CREDENTIALS="$(pwd)/$KEY_FILE"

# Initialize Terraform if .terraform directory doesn't exist
if [ ! -d ".terraform" ]; then
    log_message "Initializing Terraform..."
    terraform init
else
    log_message "Terraform already initialized"
fi

# Show the plan
log_message "Planning Terraform changes..."
terraform plan

log_message "Applying Terraform changes..."
terraform apply -auto-approve

# Monitor the startup script
if ! monitor_startup_script; then
    log_message "Warning: VM startup script encountered issues."
    log_message "You can check the full startup logs in the GCP Console or using:"
    log_message "gcloud compute instances get-serial-port-output fastapi-server --zone=\$(terraform output -raw zone)"
fi

# Get the outputs
log_message "Deployment complete! Server details:"
echo "Server IP: $(terraform output -raw server_ip)"
echo "Server URL: $(terraform output -raw server_url)"
echo "VM Service Account: $(terraform output -raw vm_service_account_email)"

# Test server health
log_message "Testing server health..."
server_url=$(terraform output -raw server_url)
max_attempts=6
attempt=1
wait_time=10

while [ $attempt -le $max_attempts ]; do
    if curl -s "$server_url/health" | grep "healthy" >/dev/null; then
        log_message "Server is healthy and responding!"
        break
    fi
    log_message "Server not ready yet... (attempt $attempt/$max_attempts)"
    sleep $wait_time
    attempt=$((attempt + 1))
done

if [ $attempt -gt $max_attempts ]; then
    log_message "Warning: Could not confirm server health. You may need to wait a few more minutes."
    log_message "Try checking the health endpoint manually: $server_url/health"
fi 