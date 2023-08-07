# !/usr/bin/env sh


repo_url="https://github.com/swiftwave-org/installer/archive/refs/heads/main.zip"
installer_path="$PWD/swiftwave-installer"

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

# Run setup script
echo "Starting ..."
sudo chmod +x setup.sh
bash setup.sh