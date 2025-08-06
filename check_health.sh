#!/bin/bash

# Function to log messages with timestamp
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Get server URL from terraform output
SERVER_URL=$(terraform output -raw server_url)
if [ $? -ne 0 ]; then
    log_message "Error: Failed to get server URL. Make sure terraform is initialized and the server is deployed."
    exit 1
fi

# Function to check health endpoint
check_health() {
    local response
    local status_code
    
    log_message "Checking health endpoint at: $SERVER_URL/health"
    
    # Use curl to get both status code and response body
    response=$(curl -s -w "\n%{http_code}" "$SERVER_URL/health")
    status_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed \$d)
    
    if [ "$status_code" = "200" ]; then
        log_message "✅ Server is healthy!"
        log_message "Response: $body"
        return 0
    else
        log_message "❌ Server health check failed!"
        log_message "Status code: $status_code"
        [ ! -z "$body" ] && log_message "Response: $body"
        return 1
    fi
}

# Try health check with retries
MAX_ATTEMPTS=6
WAIT_TIME=10
attempt=1

while [ $attempt -le $MAX_ATTEMPTS ]; do
    if check_health; then
        exit 0
    fi
    
    if [ $attempt -lt $MAX_ATTEMPTS ]; then
        log_message "Retrying in ${WAIT_TIME} seconds... (attempt $attempt/$MAX_ATTEMPTS)"
        sleep $WAIT_TIME
    fi
    attempt=$((attempt + 1))
done

log_message "Health check failed after $MAX_ATTEMPTS attempts."
exit 1 