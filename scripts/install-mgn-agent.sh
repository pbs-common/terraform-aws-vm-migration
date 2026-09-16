#!/usr/bin/env bash
set -euo pipefail

directory_path="/opt/mgn"
installer_uri="https://aws-application-migration-service-us-east-1.s3.us-east-1.amazonaws.com/latest/linux/aws-replication-installer-init"
installer_path="$directory_path/aws-replication-installer-init"
region="us-east-1"
aws_access_key_id="ACCESSKEY"
aws_secret_access_key="SECRETACCESSKEY"

# The installer creates the aws-replication user and adds it to sudoers, so it needs root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root (try: sudo $0)" >&2
    exit 1
fi

# Create directory if it doesn't exist
mkdir -p "$directory_path"

# Download the installer
if command -v curl >/dev/null 2>&1; then
    curl -fsSL -o "$installer_path" "$installer_uri"
else
    wget -q -O "$installer_path" "$installer_uri"
fi
chmod +x "$installer_path"

# Pass credentials through the environment so they stay out of the process list
export AWS_ACCESS_KEY_ID="$aws_access_key_id"
export AWS_SECRET_ACCESS_KEY="$aws_secret_access_key"

# Run the installer, replicating all detected disks
"$installer_path" --region "$region" --no-prompt --user-provided-id "$(hostname)"
