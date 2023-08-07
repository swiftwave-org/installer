# !/usr/bin/env sh

STACK_NAME="swiftwave"
SWARM_NETWORK="swarm_network"
SWIFTWAVE_FOLDER="$HOME/swiftwave"

# Remove docker stack
echo "Deleting docker stack..."
sudo docker stack rm $STACK_NAME &> /dev/null 2>&1

# Remove swiftwave folder
echo "Deleting swiftwave folder..."
sudo rm -rf "$SWIFTWAVE_FOLDER"

# Remove swarm network
echo "Deleting swarm network..."
sudo docker network rm $SWARM_NETWORK &> /dev/null 2>&1

echo "Uninstall completed successfully"