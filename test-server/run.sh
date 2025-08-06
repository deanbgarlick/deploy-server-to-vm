#!/bin/bash
set -e

# Log function
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    logger -t run-script "$1"
}

log_message "Starting FastAPI server..."
exec uvicorn server.app:app --host 0.0.0.0 --port 8000 