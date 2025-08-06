#!/bin/bash

# Create secrets directory if it doesn't exist
mkdir -p secrets

# 1. Generate the key (no passphrase for automated use)
ssh-keygen -t ed25519 -C "vm-deployment" -f deploy_key -N ""

# 2. Display the public key to copy
echo "=== Copy this public key to GitHub deploy keys ==="
cat deploy_key.pub
echo "================================================"
echo "Add this key at: https://github.com/deanbgarlick/hello-world-app-server/settings/keys"
echo "Title: VM Deployment Key"
echo "DO NOT check 'Allow write access'"

# 3. Move private key to secrets and cleanup
mv deploy_key secrets/github_deploy_key

echo "Private key has been moved to secrets/github_deploy_key"