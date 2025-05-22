#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}Installing Network Tools...${NC}"

# All scripts must be made executable
find scripts/ -type f -name "*.sh" -exec chmod +x {} \;
echo -e "${GREEN}✓${NC} Made scripts executable"
echo -e "\n${GREEN}Checking dependencies...${NC}"

check_dependency() {
	if ! command -v $1 &> /dev/null; then
		echo -e "${YELLOW}⚠ $1 not found. Some features may not work.${NC}"
		MISSING_DEPS="$MISSING_DEPS $1"
		return 1
	else
		echo -e "${GREEN}✓${NC} $1 found"
		return 0
	fi
}

MISSING_DEPS=""

# Essential tools
check_dependency ping
check_dependency nmap
check_dependency curl
check_dependency arp

# Optional but recommended
check_dependency tcpdump
check_dependency iperf3
check_dependency ffmpeg
check_dependency netstat

# If anything is missing, suggest installation
if [ ! -z "$MISSING_DEPS" ]; then
    echo -e "\n${YELLOW}Some dependencies are missing.${NC}"
    
    # Detect OS
    if [ -f /etc/debian_version ]; then
        echo -e "You can install them on Debian/Ubuntu with:"
        echo -e "${GREEN}sudo apt update && sudo apt install$MISSING_DEPS${NC}"
    elif [ -f /etc/redhat-release ]; then
        echo -e "You can install them on CentOS/Fedora with:"
        echo -e "${GREEN}sudo dnf install$MISSING_DEPS${NC}"
    elif [ -f /etc/arch-release ]; then
        echo -e "You can install them on Arch with:"
        echo -e "${GREEN}sudo pacman -S$MISSING_DEPS${NC}"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo -e "You can install them on macOS with:"
        echo -e "${GREEN}brew install$MISSING_DEPS${NC}"
    fi
    
    read -p "Would you like to continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}Installation aborted.${NC}"
        exit 1
    fi
fi

# Create config file with common settings
if [ ! -f utils/config.sh ]; then
    echo -e "\n${GREEN}Creating configuration file...${NC}"
    mkdir -p utils
    cat > utils/config.sh << 'EOL'
#!/bin/bash

# Default network settings
DEFAULT_NETWORK="192.168.1.0/24"
DEFAULT_ROUTER="192.168.1.1"
DEFAULT_INTERFACE="$(ip route | grep default | awk '{print $5}' | head -n1)"

# Timing settings
DEFAULT_TIMEOUT=2
DEFAULT_INTERVAL=60

# Logging settings
LOG_DIR="$HOME/.iot-network-tools/logs"
mkdir -p "$LOG_DIR"
EOL
    chmod +x utils/config.sh
    echo -e "${GREEN}✓${NC} Created config file at utils/config.sh"
fi

echo -e "\n${GREEN}Installation complete!${NC}"
echo -e "Run scripts from the scripts/ directory. For example:"
echo -e "${GREEN}./scripts/discovery/find_devices.sh${NC}"
echo -e "\nSee the README.md file for more information and usage examples."
