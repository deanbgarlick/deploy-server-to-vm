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

log_message "Starting server setup..."

# Update and install dependencies
log_message "Updating package lists..."
time_operation apt-get update

log_message "Installing required packages..."
time_operation apt-get install -y python3-pip git nginx
if [ $? -eq 0 ]; then
  log_message "Successfully installed required packages"
else
  log_message "Error: Failed to install required packages"
  exit 1
fi

# Install monitoring agent
log_message "Installing Google Cloud Ops agent..."
time_operation bash -c 'curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh && bash add-google-cloud-ops-agent-repo.sh --also-install'

# Create application directory
log_message "Creating application directory..."
mkdir -p /app
cd /app

# Copy application files from startup script
log_message "Setting up application files..."
cat <<'APPEOF' > /app/requirements.txt
${requirements_content}
APPEOF

mkdir -p /app/server
cat <<'APPEOF' > /app/server/app.py
${app_content}
APPEOF

# Install Python dependencies
cd /app
log_message "Installing Python dependencies..."
time_operation pip3 install -r requirements.txt
if [ $? -eq 0 ]; then
  log_message "Successfully installed Python dependencies"
else
  log_message "Error: Failed to install Python dependencies"
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
WorkingDirectory=/app
ExecStart=/usr/local/bin/uvicorn server.app:app --host 0.0.0.0 --port 8000
Restart=always
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOT

# Configure nginx
log_message "Configuring nginx..."
cat <<EOT > /etc/nginx/sites-available/fastapi
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://localhost:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOT

ln -s /etc/nginx/sites-available/fastapi /etc/nginx/sites-enabled/
rm /etc/nginx/sites-enabled/default

log_message "Restarting nginx..."
time_operation systemctl restart nginx
if [ $? -eq 0 ]; then
  log_message "Successfully restarted nginx"
else
  log_message "Error: Failed to restart nginx"
  exit 1
fi

# Start the FastAPI service
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