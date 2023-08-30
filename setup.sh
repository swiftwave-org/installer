# !/usr/bin/env sh

STACK_NAME="swiftwave"
SWARM_NETWORK="swarm_network"
SWIFTWAVE_FOLDER="$HOME/swiftwave"

if [[ $ENVIRONMENT == "" ]]
then
    export ENVIRONMENT="production"
fi

# Functions

# Check already installation
check_already_installed() {
    if [ -d "$SWIFTWAVE_FOLDER" ]; then
        if [[ $ENVIRONMENT == "production" ]]
        then
            echo "Swiftwave is already installed."
            read -p "Do you like to reinstall swiftwave? (y/n) " reinstall_choice
            # if yes, delete swiftwave folder
            if [ "$reinstall_choice" = "y" ]; then
                echo "Deleting swiftwave folder..."
                sudo rm -rf "$SWIFTWAVE_FOLDER"
                echo "Swiftwave folder deleted successfully"
                echo "Deleting docker stack..."
                sudo docker stack rm $STACK_NAME &> /dev/null 2>&1
                echo "Docker stack deleted successfully"
                echo "Waiting for 30 seconds..."
                sleep 30
            else
                echo "Exiting..."
                exit 1
            fi
        elif [[ $ENVIRONMENT == "staging" ]]
        then
            sudo rm -rf "$SWIFTWAVE_FOLDER"
            sudo docker stack rm $STACK_NAME &> /dev/null 2>&1
            sleep 30
        else
            echo "Wrong environment selected."
            exit 1
        fi
    fi
}

# Install dependencies
install_dependencies(){
    sudo apt update -y
    sudo apt install -y apt-transport-https ca-certificates curl gnupg2 software-properties-common
    sudo apt install -y openssl apache2-utils curl
    clear
}

# Generate pem file
# Input : $1 - file name
generate_pem_file() {
    openssl genpkey -algorithm RSA -out private_key.pem -pkeyopt rsa_keygen_bits:2048 > /dev/null 2>&1
    openssl req -new -key private_key.pem -out csr.pem -subj "/C=XX" > /dev/null 2>&1
    openssl x509 -req -days 365 -in csr.pem -signkey private_key.pem -out certificate.pem > /dev/null 2>&1
    cat certificate.pem private_key.pem > "$1"
    # Remove temp files
    rm csr.pem
    rm private_key.pem
    rm certificate.pem
}

# Install docker
install_docker() {
    echo "Docker is not installed. Install docker : https://docs.docker.com/engine/install/"
    if [[ "$ENVIRONMENT" == "production" ]]
    then
        read -p "Do you like to install docker? (y/n) " install_docker_choice
    fi

    # if yes, install docker
    if [[ "$ENVIRONMENT" == "staging" || "$install_docker_choice" = "y" ]]; then
        echo "Installing docker..."
        sudo apt update -y
        sudo apt install -y apt-transport-https ca-certificates curl gnupg2 software-properties-common
        sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
        sudo add-apt-repository  --yes "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
        sudo apt update -y
        sudo apt install -y docker-ce docker-ce-cli containerd.io
        clear
        echo "Docker installed successfully"
    else
        echo "Docker is required to run this project. Exiting..."
        exit 1
    fi
}

# Start

# User should run as non root user
if [ "$EUID" -eq 0 ]; then
    echo "Please run as non-root user [without sudo]"
    exit 1
fi

# Install dependencies
install_dependencies

# Check for previous installation
check_already_installed

# Check if docker and docker compose are installed
if ! command -v docker &>/dev/null; then
    install_docker
fi

# Check if docker swarm is initialized
if ! sudo docker info | grep -q "Swarm: active"; then
    echo "Docker swarm is not initialized. Initializing docker swarm..."
    sudo docker swarm init > /dev/null 2>&1
    echo "Docker swarm initialized successfully"
fi

# Find current node details from docker swarm
node_id=$(sudo docker node ls | grep $(hostname) | awk '{print $1}')
if [ -z "$node_id" ]; then
    echo "Node id not found. Exiting..."
    exit 1
fi

# Add label swiftwave_controlplane_node=true to current node
sudo docker node update --label-add swiftwave_controlplane_node=true "$node_id" > /dev/null 2>&1

# Create docker network
if ! sudo docker network ls | grep -q $SWARM_NETWORK; then
    echo "Creating docker network..."
    sudo docker network create --driver=overlay --attachable $SWARM_NETWORK > /dev/null 2>&1
    echo "Docker network created successfully"
else
    echo "Docker network already exists"
fi

# Delete swiftwave folder if exists
if [ -d "$SWIFTWAVE_FOLDER" ]; then
    echo "Swiftwave folder already exists. Deleting swiftwave folder..."
    sudo rm -rf "$SWIFTWAVE_FOLDER"
    echo "Swiftwave folder deleted successfully"
fi

# Create swiftwave folder
echo "Creating swiftwave folder..."
mkdir "$SWIFTWAVE_FOLDER"
echo "Swiftwave folder created successfully"

SWIFTWAVE_APP_FOLDER="$SWIFTWAVE_FOLDER/app"
SWIFTWAVE_APP_TARBALL_FOLDER="$SWIFTWAVE_FOLDER/app/tarball"
SWIFTWAVE_REDIS_FOLDER="$SWIFTWAVE_FOLDER/redis"
SWIFTWAVE_HAPROXY_FOLDER="$SWIFTWAVE_FOLDER/haproxy"

# Create subfolders
mkdir "$SWIFTWAVE_APP_FOLDER"
mkdir "$SWIFTWAVE_APP_TARBALL_FOLDER"
mkdir "$SWIFTWAVE_REDIS_FOLDER"
mkdir "$SWIFTWAVE_HAPROXY_FOLDER"
mkdir "$SWIFTWAVE_HAPROXY_FOLDER/ssl"

# Generate default pem file
# as haproxy ssl_sni is enabled, without atleast one pem file, haproxy will not start
generate_pem_file "$SWIFTWAVE_HAPROXY_FOLDER/ssl/default.pem"

if [[ "$ENVIRONMENT" == "production" ]]
then
    # Take admin username and password
    while true; do
        echo "This e-mail id will be used to used in requesting SSL certificate from Let's Encrypt, So make sure this email id is valid and you have access to it."
        read -p "Enter admin email : " admin_email
        read -p "Enter admin username : " admin_username
        read -p "Enter admin password : " admin_password

        # Check if admin email is empty
        if [ -z "$admin_email" ]; then
            echo "Admin email cannot be empty"
            continue
        fi

        # Check if admin username is empty
        if [ -z "$admin_username" ]; then
            echo "Admin username cannot be empty"
            continue
        fi
        # Check if admin password is empty
        if [ -z "$admin_password" ]; then
            echo "Admin password cannot be empty"
            continue
        fi
        break
    done
elif [[ "$ENVIRONMENT" == "staging" ]]
then
    admin_email="test@gmail.com"
    admin_username="admin"
    admin_password="admin"
else
    echo "Wrong environment selected."
    exit 1
fi


# Generate brypt hash of admin password
admin_password_hash=$(htpasswd -bnBC 8 "" "$admin_password"  | grep -oP '\$2[ayb]\$.{56}' | base64 -w 0)

# admin username and password hash
SWIFTWAVE_ADMIN_EMAIL="$admin_email"
SWIFTWAVE_ADMIN_USERNAME="$admin_username"
SWIFTWAVE_ADMIN_PASSWORD_HASH="$admin_password_hash"

# Read docker-compose.yml
docker_compose_yml=$(cat docker-compose.yml)

# Use sed to replace env variables in docker-compose.yml
docker_compose_yml=$(echo "$docker_compose_yml" | sed "s|\${SWIFTWAVE_APP_FOLDER}|$SWIFTWAVE_APP_FOLDER|g")
docker_compose_yml=$(echo "$docker_compose_yml" | sed "s|\${SWIFTWAVE_APP_TARBALL_FOLDER}|$SWIFTWAVE_APP_TARBALL_FOLDER|g")
docker_compose_yml=$(echo "$docker_compose_yml" | sed "s|\${SWIFTWAVE_REDIS_FOLDER}|$SWIFTWAVE_REDIS_FOLDER|g")
docker_compose_yml=$(echo "$docker_compose_yml" | sed "s|\${SWIFTWAVE_HAPROXY_FOLDER}|$SWIFTWAVE_HAPROXY_FOLDER|g")
docker_compose_yml=$(echo "$docker_compose_yml" | sed "s|\${SWIFTWAVE_ADMIN_EMAIL}|$SWIFTWAVE_ADMIN_EMAIL|g")
docker_compose_yml=$(echo "$docker_compose_yml" | sed "s|\${SWIFTWAVE_ADMIN_USERNAME}|$SWIFTWAVE_ADMIN_USERNAME|g")
docker_compose_yml=$(echo "$docker_compose_yml" | sed "s|\${SWIFTWAVE_ADMIN_PASSWORD_HASH}|$SWIFTWAVE_ADMIN_PASSWORD_HASH|g")
docker_compose_yml=$(echo "$docker_compose_yml" | sed "s|\${SWARM_NETWORK}|$SWARM_NETWORK|g")


# Read IP address of current node
ip_address=$(curl --silent https://api64.ipify.org/)
if [[ "$ENVIRONMENT" == "production" ]]
then
    echo "Public IP of current node is $ip_address"
    read -p "Are you sure this is the correct IP address of current node? (y/n) " choice
    if [ "$choice" != "y" ]; then
        read -p "Enter IP address of current node : " ip_address
    fi
fi

# Read haproxy.cfg
haproxy_cfg=$(cat haproxy.cfg)

# Use sed to replace env variables in haproxy.cfg
haproxy_cfg=$(echo "$haproxy_cfg" | sed "s|\${PUBLIC_IP}|$ip_address|g")

# Write docker-compose-raw.yml
echo "$docker_compose_yml" > docker-compose-raw.yml

# Write haproxy.cfg
echo "$haproxy_cfg" > "$SWIFTWAVE_HAPROXY_FOLDER/haproxy.cfg"

# Permission update
sudo chown root:root "$SWIFTWAVE_FOLDER"
sudo chown root:root "$SWIFTWAVE_APP_FOLDER"
sudo chown root:root "$SWIFTWAVE_APP_TARBALL_FOLDER"
sudo chown root:root "$SWIFTWAVE_REDIS_FOLDER"
sudo chown root:root "$SWIFTWAVE_HAPROXY_FOLDER"
sudo chown root:root "$SWIFTWAVE_HAPROXY_FOLDER/ssl"

# Start the services
sudo docker stack deploy -c docker-compose-raw.yml $STACK_NAME

# Clean up
rm docker-compose-raw.yml