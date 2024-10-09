# File Downloader and Uploader Script

This repository contains two main scripts: `downloader.sh` and `upload_and_clean.sh`. These scripts are designed to help you download files from the internet, monitor disk usage during the download, and upload the downloaded files to OneDrive. Additionally, the scripts clean up the local files after uploading.

## Table of Contents
- [File Downloader and Uploader Script](#file-downloader-and-uploader-script)
  - [Table of Contents](#table-of-contents)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
  - [How it Works](#how-it-works)

## Prerequisites

Before using these scripts, ensure you have the following installed on your system:

- `wget`: A command-line utility for downloading files from the web.
- `rclone`: A command-line program to manage files on cloud storage.
- Access to OneDrive or any other cloud storage supported by `rclone`.


## Installation

1. Clone this repository to your local machine:
   ```sh
   git clone https://github.com/stag7824/Scripts
   cd yourrepository

2. Install `wget` and `rclone` if they are not already installed:
    ```sh
    sudo apt-get install wget
    
    curl https://rclone.org/install.sh | sudo bash
    ```
3. Configure `rclone` to work with your OneDrive account:
    ```sh
    rclone config
    ```
    Follow the prompts to set up your OneDrive remote.
4. Make the scripts executable:
   ```sh
   chmod +x downloadScript.sh
   chmod +x upload_and_clean.sh
    ```

## Usage

1. **downloader.sh:**

- Replace "URL_TO_DOWNLOAD" with the actual URL you want to download.
Set the MAX_DISK_USAGE variable to the maximum disk usage limit in GB.
2. **upload_and_clean.sh:**

- Set the REMOTE_FOLDER variable to the desired folder in your OneDrive where the files will be uploaded.
Ensure that the LOCAL_FILE and ZIP_FILE variables are correctly set to the paths of the files you want to upload and clean.


## Running the Scripts
1. **Download Files**: Run the downloader.sh to start downloading files:
    ```sh
    ./downloader.sh
    ```
2. **Upload and Clean Files**:  After the download is complete, run the upload_and_clean.sh script to upload the files to OneDrive and clean up the local files:
   ```sh
   ./upload_and_clean.sh
   ```
## How it Works
**downloader.sh**

This script downloads a file from a specified URL and monitors disk usage during the download. If the disk usage exceeds a specified limit, the download is stopped.

- The script starts the `wget` download in the background and captures its process ID.
- It then monitors the disk usage every 5 seconds.
- If the disk usage exceeds the specified limit, the download is stopped, and an error message is displayed.

**upload_and_clean.sh**

This script uploads the downloaded files to OneDrive and removes the local copies after the upload is complete.

The script uses `rclone` to copy the specified files to the configured OneDrive remote folder.
- After the upload is complete, the script removes the original and compressed files from the local machine.
- Finally, it prints a message indicating that all files have been processed successfully.
- By following these instructions, you can customize and use the scripts to download files, monitor disk usage, upload files to OneDrive, and clean up local files efficiently.
   
