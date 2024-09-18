#!/bin/bash

# Exit immediately if a command exits with a non-zero status, and treat unset variables as an error
set -euo pipefail

# Function to clean up temporary files
cleanup() {
    echo "Cleaning up temporary files..."
    if [ -f "$LOCAL_FILE" ]; then
        rm -f "$LOCAL_FILE"
    fi
    if [ -f "$ZIP_FILE" ]; then
        rm -f "$ZIP_FILE"
    fi
}

# Trap signals and errors to ensure cleanup is called
trap cleanup EXIT INT TERM

# Function to convert bytes to gigabytes
function human_readable() {
    local bytes=$1
    local gib=$(awk "BEGIN {printf \"%.2f\", $bytes/1024/1024/1024}")
    echo "$gib"
}

# Check if URL is provided
if [ $# -eq 0 ]; then
    echo "Usage: ./download_and_upload.sh [URL]"
    exit 1
fi

DOWNLOAD_URL="$1"
REMOTE_FOLDER="VPS-Uploads"

# Extract filename from URL
FILENAME=$(basename "${DOWNLOAD_URL%%\?*}")

# Define local paths
LOCAL_FILE="/tmp/$FILENAME"
ZIP_FILE="$LOCAL_FILE.zip"

# Maximum allowed file size in bytes (30GB)
MAX_FILE_SIZE=$((30 * 1024 * 1024 * 1024))

# Maximum allowed disk usage in GB
MAX_DISK_USAGE=150

# Check available disk space before downloading
AVAILABLE_DISK_SPACE=$(df --output=avail -BG / | tail -1 | tr -dc '0-9')

if [ "$AVAILABLE_DISK_SPACE" -lt "$MAX_DISK_USAGE" ]; then
    echo "Not enough disk space available. Required: $MAX_DISK_USAGE GB, Available: $AVAILABLE_DISK_SPACE GB."
    exit 1
fi

# Check remote file size (works for HTTP/HTTPS)
FILE_SIZE=$(curl -sI "$DOWNLOAD_URL" | grep -i '^Content-Length' | awk '{print $2}' | tr -d '\r')

if [ -z "$FILE_SIZE" ]; then
    echo "Could not determine file size. Proceed anyway? (y/n)"
    read -r CONFIRMATION
    if [ "$CONFIRMATION" != "y" ]; then
        echo "Download aborted."
        exit 1
    fi
else
    if [ "$FILE_SIZE" -gt "$MAX_FILE_SIZE" ]; then
        echo "File size exceeds 30GB limit."
        echo "File size: $(human_readable "$FILE_SIZE") GB"
        echo "Proceed anyway? (y/n)"
        read -r CONFIRMATION
        if [ "$CONFIRMATION" != "y" ]; then
            echo "Download aborted."
            exit 1
        fi
    fi
fi

# Function to monitor disk usage during download
monitor_disk_usage() {
    while sleep 5; do
        CURRENT_DISK_USAGE=$(df --output=used -BG / | tail -1 | tr -dc '0-9')
        if [ "$CURRENT_DISK_USAGE" -gt "$MAX_DISK_USAGE" ]; then
            echo "Disk usage exceeded $MAX_DISK_USAGE GB. Stopping download."
            kill "$WGET_PID" 2>/dev/null || true
            exit 1
        fi
    done
}

# Start monitoring disk usage in the background
monitor_disk_usage &
MONITOR_PID=$!

# Download the file
echo "Starting download..."
wget -O "$LOCAL_FILE" "$DOWNLOAD_URL" &
WGET_PID=$!
wait $WGET_PID || { echo "Download failed."; kill "$MONITOR_PID"; exit 1; }

# Stop the disk usage monitor
kill "$MONITOR_PID"

# Compress the file
echo "Compressing the file..."
zip -r "$ZIP_FILE" "$LOCAL_FILE"

# Remove the original file
rm -f "$LOCAL_FILE"

# Upload to oneDrive using rclone
echo "Uploading the zip file to oneDrive..."
rclone copy "$ZIP_FILE" oneDrive:"$REMOTE_FOLDER"/

# Remove the zip file locally
rm -f "$ZIP_FILE"

echo "Process completed successfully."
