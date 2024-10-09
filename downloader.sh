#!/bin/bash

# Exit immediately if a command exits with a non-zero status, and treat unset variables as an error
set -euo pipefail

# Function to clean up temporary files
cleanup() {
    echo "Cleaning up temporary files..."
    if [ -f "$LOCAL_FILE" ]; then
        rm -f "$LOCAL_FILE"
    fi
    if [ -f "$ARCHIVE_FILE" ]; then
        rm -f "$ARCHIVE_FILE"
    fi
}
trap cleanup EXIT INT TERM

# Default settings
ZIP_ENABLED=true
PASSWORD_ENABLED=true
ZIP_PASSWORD="123"  # Default password; consider changing this or prompting the user
REMOTE_FOLDER="VPS-Uploads"
MAX_FILE_SIZE=$((30 * 1024 * 1024 * 1024))  # 30GB
MAX_DISK_USAGE=150  # 150GB

# Parse flags
while [[ $# -gt 0 ]]; do
    case $1 in
        -z:*)
            ZIP_OPTION="${1#-z:}"
            if [ "$ZIP_OPTION" = "false" ]; then
                ZIP_ENABLED=false
            fi
            shift
            ;;
        -p:*)
            PASSWORD_OPTION="${1#-p:}"
            if [ "$PASSWORD_OPTION" = "false" ]; then
                PASSWORD_ENABLED=false
            fi
            shift
            ;;
        *)
            if [ -z "${DOWNLOAD_URL:-}" ]; then
                DOWNLOAD_URL="$1"
            else
                echo "Unknown parameter or multiple URLs provided."
                exit 1
            fi
            shift
            ;;
    esac
done

# Check if URL is provided
if [ -z "${DOWNLOAD_URL:-}" ]; then
    echo "Usage: ./download_and_upload.sh [options] [URL]"
    echo "Options:"
    echo "  -z:true|false    Enable or disable zipping (default: true)"
    echo "  -p:true|false    Enable or disable password protection (default: true)"
    exit 1
fi

# Function to convert bytes to gigabytes
human_readable() {
    local bytes=$1
    local gib=$(awk "BEGIN {printf \"%.2f\", $bytes/1024/1024/1024}")
    echo "$gib"
}

# Extract filename from URL
FILENAME=$(basename "${DOWNLOAD_URL%%\?*}")
LOCAL_FILE="/tmp/$FILENAME"
ARCHIVE_FILE="$LOCAL_FILE"

if [ "$ZIP_ENABLED" = true ]; then
    ARCHIVE_FILE="$LOCAL_FILE.zip"
fi

# Check available disk space before downloading
AVAILABLE_DISK_SPACE=$(df --output=avail -BG / | tail -1 | tr -dc '0-9')

if [ "$AVAILABLE_DISK_SPACE" -lt "$MAX_DISK_USAGE" ]; then
    echo "Not enough disk space available. Required: $MAX_DISK_USAGE GB, Available: $AVAILABLE_DISK_SPACE GB."
    exit 1
fi

# Check remote file size
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

# Compress the file if enabled
if [ "$ZIP_ENABLED" = true ]; then
    echo "Compressing the file..."
    if [ "$PASSWORD_ENABLED" = true ]; then
        zip -r -P "$ZIP_PASSWORD" "$ARCHIVE_FILE" "$LOCAL_FILE"
    else
        zip -r "$ARCHIVE_FILE" "$LOCAL_FILE"
    fi
    # Remove the original file
    rm -f "$LOCAL_FILE"
fi

# Upload to oneDrive using rclone
echo "Uploading the file to oneDrive..."
rclone copy "$ARCHIVE_FILE" oneDrive:"$REMOTE_FOLDER"/

# Remove the archive file locally
rm -f "$ARCHIVE_FILE"

echo "Process completed successfully."
