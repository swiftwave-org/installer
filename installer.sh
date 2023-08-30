#!/usr/bin/env bash


repo_url="https://github.com/swiftwave-org/installer/archive/refs/heads/main.zip"
installer_path="$PWD/swiftwave-installer"

# Remove existing swiftwave-installer directory
if [ -d "$installer_path" ]; then
    sudo rm -rf $installer_path &> /dev/null
fi

# Check for `wget` command
if ! command -v wget &> /dev/null
then
    echo "wget command could not be found"
    echo "Installing wget..."
    sudo apt update -y
    sudo apt install -y wget
fi

# Check for `unzip` command
if ! command -v unzip &> /dev/null
then
    echo "unzip command could not be found"
    echo "Installing unzip..."
    sudo apt update -y
    sudo apt install -y unzip
fi

# Clone swiftwave repository
echo "Downloading installer..."
wget -qO- $repo_url > installer.zip
echo "Extracting to $installer_path"
unzip -qq installer.zip -d $installer_path
rm installer.zip

# Change directory to swiftwave-installer
cd $installer_path

# Move everything from `installer-main` to current directory
mv installer-main/* .
rm -rf installer-main

# Run setup script
echo "Starting ..."
sudo chmod +x setup.sh
bash -c "./setup.sh < /dev/tty0"
