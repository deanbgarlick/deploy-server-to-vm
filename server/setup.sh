#!/bin/bash
set -e

# Log function
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    logger -t setup-script "$1"
}

log_message "Installing Python dependencies..."
pip3 install -r requirements.txt

log_message "Test server setup completed successfully!" 