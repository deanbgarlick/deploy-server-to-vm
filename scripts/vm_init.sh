#!/bin/bash

# Function to log messages to both stdout and Google Cloud Logging
log_message() {
  local message="$1"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message"
  logger -t startup-script "$message"
}

# Function to time operations
time_operation() {
  local start_time=$(date +%s)
  "$@"
  local status=$?
  local end_time=$(date +%s)
  local duration=$((end_time - start_time))
  log_message "Operation took $duration seconds: $1"
  return $status
}

# Function to retry a command
retry_command() {
    local max_attempts=5
    local delay=15
    local attempt=1
    local command="$@"
    
    while [ $attempt -le $max_attempts ]; do
        log_message "Attempt $attempt of $max_attempts: $1"
        if eval "$command"; then
            return 0
        fi
        log_message "Command failed. Waiting $delay seconds before retrying..."
        sleep $delay
        attempt=$((attempt + 1))
        delay=$((delay * 2))
    done
    
    log_message "Error: Command failed after $max_attempts attempts"
    return 1
}

log_message "Starting server setup..."

# Update and install dependencies with retry
log_message "Updating package lists..."
if ! retry_command "apt-get update"; then
    log_message "Error: Failed to update package lists after multiple attempts"
    exit 1
fi

log_message "Installing required packages..."
if ! retry_command "apt-get install -y python3-pip git nginx"; then
    log_message "Error: Failed to install required packages after multiple attempts"
    exit 1
fi

# Install monitoring agent
log_message "Installing Google Cloud Ops agent..."
time_operation bash -c 'curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh && bash add-google-cloud-ops-agent-repo.sh --also-install'

# Create application directory
log_message "Creating application directory..."
mkdir -p /app
cd /app

# Deploy based on mode
if [ "${deployment_mode}" = "github_public" ]; then
    log_message "Cloning public GitHub repository..."
    if ! git clone --branch "${github_branch}" "${github_repo_url}" /app/repo; then
        log_message "Error: Failed to clone repository"
        exit 1
    fi
    APP_DIR="/app/repo"
elif [ "${deployment_mode}" = "github_private" ]; then
    log_message "Setting up SSH for private GitHub repository..."
    # Setup SSH for GitHub only
    mkdir -p /root/.ssh
    chmod 700 /root/.ssh
    
    # Create a GitHub-specific SSH config
    cat <<EOT > /root/.ssh/config
Host github.com
    HostName github.com
    IdentityFile /root/.ssh/github_deploy_key
    IdentitiesOnly yes
EOT
    chmod 600 /root/.ssh/config
    
    # Save the key with a specific name
    echo "${github_ssh_key}" > /root/.ssh/github_deploy_key
    chmod 600 /root/.ssh/github_deploy_key
    
    # Add only GitHub to known hosts
    ssh-keyscan github.com > /root/.ssh/known_hosts
    chmod 600 /root/.ssh/known_hosts
    
    # Configure Git to use HTTPS for everything except GitHub
    git config --global url."https://".insteadOf git://
    git config --global url."git@github.com:".insteadOf "https://github.com/"
    
    log_message "Cloning private GitHub repository..."
    if ! git clone --branch "${github_branch}" "${github_repo_url}" /app/repo; then
        log_message "Error: Failed to clone repository"
        exit 1
    fi
    APP_DIR="/app/repo"
else
    log_message "Setting up local test server..."
    mkdir -p /app/repo
    # Copy our test server files
    cat <<'APPEOF' > /app/repo/setup.sh
${setup_script_content}
APPEOF

    cat <<'APPEOF' > /app/repo/run.sh
${run_script_content}
APPEOF

    cat <<'APPEOF' > /app/repo/requirements.txt
${requirements_content}
APPEOF

    mkdir -p /app/repo/server
    cat <<'APPEOF' > /app/repo/server/app.py
${app_content}
APPEOF
    APP_DIR="/app/repo"
fi

# Make scripts executable
log_message "Making scripts executable..."
chmod +x $APP_DIR/setup.sh $APP_DIR/run.sh

# Run setup script
log_message "Running setup script..."
cd $APP_DIR
if ! ./setup.sh; then
    log_message "Error: Setup script failed"
    exit 1
fi

# Create systemd service
log_message "Creating systemd service..."
cat <<EOT > /etc/systemd/system/fastapi.service
[Unit]
Description=FastAPI application
After=network.target

[Service]
User=root
WorkingDirectory=$APP_DIR
ExecStart=$APP_DIR/run.sh
Restart=always
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOT

# Start the service
log_message "Starting FastAPI service..."
systemctl enable fastapi
time_operation systemctl start fastapi
if [ $? -eq 0 ]; then
    log_message "Successfully started FastAPI service"
else
    log_message "Error: Failed to start FastAPI service"
    exit 1
fi

log_message "Server setup completed successfully!" 