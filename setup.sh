# !/usr/bin/env sh

# Check if docker and docker compose are installed
if ! command -v docker &>/dev/null; then
    echo "Docker is not installed. Install docker : https://docs.docker.com/engine/install/"
    echo "Do you like to install docker? (y/n)"
    read -r install_docker
    # if yes, install docker
    if [ "$install_docker" = "y" ]; then
        echo "Installing docker..."
        sudo apt update -y
        sudo apt install -y apt-transport-https ca-certificates curl gnupg2 software-properties-common
        sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
        sudo add-apt-repository  --yes "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
        sudo apt update -y
        sudo apt install -y docker-ce docker-ce-cli containerd.io
        echo "Docker installed successfully"
    else
        echo "Docker is required to run this project. Exiting..."
        exit 1
    fi
fi

# Check if docker swarm is initialized
if ! sudo docker info | grep -q "Swarm: active"; then
    echo "Docker swarm is not initialized. Initializing docker swarm..."
    sudo docker swarm init
    echo "Docker swarm initialized successfully"
fi

# 