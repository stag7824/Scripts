#!/bin/bash

# Exit immediately if a command exits with a non-zero status, and treat unset variables as an error
set -euo pipefail

# Folder containing torrent downloads
TORRENT_FOLDER="/home/ubuntu/Files/Torrents/complete"
REMOTE_FOLDER="VPS-Uploads"
ZIP_PASSWORD="123"

# Function to clean up after processing
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

# Function to compress and upload files
process_files() {
    # Loop through each file/folder in the torrent directory
    for FILE in "$TORRENT_FOLDER"/*; do
        # Extract the filename without path
        FILENAME=$(basename "$FILE")

        # Define local paths
        LOCAL_FILE="$TORRENT_FOLDER/$FILENAME"
        ZIP_FILE="$LOCAL_FILE.zip"

        # Compress the file/folder with password protection
        echo "Compressing $FILENAME with password..."
        zip -r -P "$ZIP_PASSWORD" "$ZIP_FILE" "$LOCAL_FILE"

        # Upload to OneDrive using rclone
        echo "Uploading $ZIP_FILE to OneDrive..."
        rclone copy "$ZIP_FILE" oneDrive:"$REMOTE_FOLDER"/

        # Remove the original file and compressed file
        echo "Removing original and compressed files..."
        rm -rf "$LOCAL_FILE" "$ZIP_FILE"
    done
}

# Run the process
process_files

echo "All files processed successfully."
