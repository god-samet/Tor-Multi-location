#!/bin/bash

# Colors for user interface
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Check for root access
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}This script must be run with root access. Please rerun it with 'sudo'.${NC}"
    exit 1
fi

# Install dependencies
echo -e "${YELLOW}Installing dependencies...${NC}"
apt update && apt install -y tor curl jq netcat cron

if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}Dependencies installed successfully.${NC}"
else
    echo -e "${RED}An error occurred while installing dependencies. Please check your network or repositories.${NC}"
    exit 1
fi

# Check and create the configuration directory
instances_dir="/etc/tor/instances"
if [[ ! -d $instances_dir ]]; then
    mkdir -p $instances_dir
    echo -e "${GREEN}Tor configuration directory created: ${instances_dir}${NC}"
fi

# Enable cron service
echo -e "${YELLOW}Enabling cron service...${NC}"
systemctl enable cron
systemctl start cron

# Ensure Tor is installed
if ! command -v tor &> /dev/null; then
    echo -e "${RED}Tor is not installed. Please check manually.${NC}"
    exit 1
fi

# Set ownership and permissions for the Tor directory
chown -R debian-tor:debian-tor $instances_dir
chmod -R 700 $instances_dir

# Copy the tor-samet script to /usr/local/bin/
echo -e "${YELLOW}Copying tor-samet script to /usr/local/bin/...${NC}"

# Create tor-samet script
cat << 'EOF' > /usr/local/bin/tor-samet
#!/bin/bash

# Path to the main script
script_name="torsamet.bash"

# Check if the main script exists
if [[ -f $script_name ]]; then
    bash $script_name
else
    echo -e "Main script (${script_name}) not found. Please make sure this file is in the same directory."
    exit 1
fi
EOF

# Set executable permissions for the tor-samet script
chmod +x /usr/local/bin/tor-samet

# Execute the main script
script_name="torsamet.sh"  # Name of the main script
if [[ -f $script_name ]]; then
    echo -e "${YELLOW}Running the main script...${NC}"
    bash $script_name
else
    echo -e "${RED}Main script (${script_name}) not found. Please make sure this file is in the same directory.${NC}"
    exit 1
fi
