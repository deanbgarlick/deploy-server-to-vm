#!/bin/bash

# Exit on any error
set -e

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to check if we can access a project
check_project_access() {
    local project=$1
    if ! gcloud projects describe "$project" &> /dev/null; then
        return 1
    fi
    return 0
}

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    log_message "Error: gcloud CLI is not installed. Please install it first."
    exit 1
fi

# Check if user is logged in to gcloud
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" &> /dev/null; then
    log_message "Error: Not logged in to gcloud. Please run 'gcloud auth login' first."
    exit 1
fi

# Prompt for project ID if not provided
if [ -z "$1" ]; then
    read -p "Enter your GCP project ID: " PROJECT_ID
else
    PROJECT_ID=$1
fi

# Check if we can access the project
if ! check_project_access "$PROJECT_ID"; then
    log_message "Error: Cannot access project '$PROJECT_ID'. Please check:"
    log_message "  1. The project ID is correct"
    log_message "  2. The project exists"
    log_message "  3. You have sufficient permissions"
    log_message "Current account: $(gcloud config get-value account)"
    exit 1
fi

# Set the project
log_message "Setting active project to $PROJECT_ID..."
if ! gcloud config set project "$PROJECT_ID"; then
    log_message "Error: Failed to set project. Aborting."
    exit 1
fi

# Create Terraform service account
TERRAFORM_SA_NAME="terraform-deployer"
TERRAFORM_SA_EMAIL="${TERRAFORM_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

log_message "Creating Terraform service account..."
gcloud iam service-accounts create $TERRAFORM_SA_NAME \
    --display-name="Terraform Deployment Service Account" \
    --description="Service account for Terraform deployments" \
    || log_message "Service account already exists"

# Grant necessary roles to Terraform service account
log_message "Granting necessary roles to Terraform service account..."
roles=(
    "roles/compute.instanceAdmin.v1"           # Manage VM instances
    "roles/compute.networkAdmin"               # Manage networking
    "roles/compute.securityAdmin"              # Manage firewall rules
    "roles/iam.serviceAccountAdmin"            # Manage service accounts
    "roles/iam.serviceAccountUser"             # Use service accounts
    "roles/compute.osLogin"                    # OS Login management
    "roles/serviceusage.serviceUsageAdmin"     # Enable APIs
    "roles/compute.viewer"                     # View compute resources
    "roles/iam.securityAdmin"                  # Manage IAM policies
)

for role in "${roles[@]}"; do
    log_message "Granting $role..."
    if ! gcloud projects add-iam-policy-binding "$PROJECT_ID" \
        --member="serviceAccount:${TERRAFORM_SA_EMAIL}" \
        --role="$role"; then
        log_message "Error: Failed to grant $role. Aborting."
        exit 1
    fi
done

# Create secrets directory if it doesn't exist
SECRETS_DIR="secrets"
mkdir -p $SECRETS_DIR
log_message "Created secrets directory"

# Create and download service account key
log_message "Creating service account key..."
KEY_FILE="$SECRETS_DIR/terraform-deployer-sa.key"
if ! gcloud iam service-accounts keys create "$KEY_FILE" \
    --iam-account="$TERRAFORM_SA_EMAIL"; then
    log_message "Error: Failed to create service account key. Aborting."
    exit 1
fi

# Make the key file read-only
chmod 400 "$KEY_FILE"

# Enable necessary APIs
log_message "Enabling necessary APIs..."
apis=(
    "compute.googleapis.com"
    "iam.googleapis.com"
    "serviceusage.googleapis.com"
    "cloudresourcemanager.googleapis.com"
)

for api in "${apis[@]}"; do
    log_message "Enabling $api..."
    if ! gcloud services enable "$api"; then
        log_message "Error: Failed to enable $api. Aborting."
        exit 1
    fi
done

# Output instructions
log_message "Setup completed successfully!"
log_message "
Next steps:
1. The service account key has been saved to:
   $KEY_FILE

2. Set up authentication for Terraform:
   export GOOGLE_APPLICATION_CREDENTIALS=$(pwd)/$KEY_FILE

3. Initialize Terraform:
   terraform init

4. Run Terraform:
   terraform plan
   terraform apply
" 