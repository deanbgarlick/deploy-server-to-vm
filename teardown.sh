#!/bin/bash

# Exit on any error
set -e

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
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

# Show what will be destroyed
log_message "Planning resource destruction..."
terraform plan -destroy

# Prompt for confirmation
read -p "Are you sure you want to destroy all resources? This cannot be undone! (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_message "Destroying all resources..."
    terraform destroy -auto-approve
    
    # Clean up local files
    log_message "Cleaning up local Terraform files..."
    rm -rf .terraform* terraform.tfstate*
    
    log_message "Teardown complete! All resources have been destroyed."
    
    # Remind about service account cleanup
    log_message "
Note: The Terraform deployer service account and its permissions still exist in GCP.
If you want to remove these as well, you can:
1. Delete the service account: gcloud iam service-accounts delete terraform-deployer@\$(gcloud config get-value project).iam.gserviceaccount.com
2. Delete the key file: rm $KEY_FILE

Or keep them if you plan to deploy again later.
"
else
    log_message "Teardown cancelled"
fi 