#!/bin/bash

# ping_test.sh - Test network connectivity using ping
# Usage: ./ping_test.sh [host] [count]

set -euo pipefail

# Default values
DEFAULT_HOST="8.8.8.8"
DEFAULT_COUNT=4
TIMEOUT=5

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display usage
usage() {
    echo "Usage: $0 [host] [count]"
    echo "  host:  Target host to ping (default: $DEFAULT_HOST)"
    echo "  count: Number of ping packets (default: $DEFAULT_COUNT)"
    echo ""
    echo "Examples:"
    echo "  $0                    # Ping Google DNS (8.8.8.8) 4 times"
    echo "  $0 google.com         # Ping google.com 4 times"
    echo "  $0 192.168.1.1 10     # Ping router 10 times"
    exit 1
}

# Function to validate if host is reachable
validate_host() {
    local host=$1
    if ! command -v ping >/dev/null 2>&1; then
        echo -e "${RED}Error: ping command not found${NC}" >&2
        exit 1
    fi
}

# Function to perform ping test
ping_test() {
    local host=$1
    local count=$2
    
    echo -e "${BLUE}=== Ping Test ===${NC}"
    echo -e "Target: ${YELLOW}$host${NC}"
    echo -e "Count: ${YELLOW}$count${NC}"
    echo -e "Timeout: ${YELLOW}${TIMEOUT}s${NC}"
    echo ""
    
    # Perform ping based on OS
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        ping_result=$(ping -c "$count" -W "$((TIMEOUT * 1000))" "$host" 2>&1)
    else
        # Linux
        ping_result=$(ping -c "$count" -W "$TIMEOUT" "$host" 2>&1)
    fi
    
    ping_exit_code=$?
    
    echo "$ping_result"
    echo ""
    
    # Analyze results
    if [ $ping_exit_code -eq 0 ]; then
        # Extract statistics
        packet_loss=$(echo "$ping_result" | grep -o '[0-9]*% packet loss' | grep -o '[0-9]*')
        avg_time=$(echo "$ping_result" | grep -o 'avg = [0-9.]*' | grep -o '[0-9.]*' || echo "N/A")
        
        if [ "$packet_loss" = "0" ]; then
            echo -e "${GREEN}✓ SUCCESS: All packets received${NC}"
        else
            echo -e "${YELLOW}⚠ WARNING: ${packet_loss}% packet loss detected${NC}"
        fi
        
        if [ "$avg_time" != "N/A" ]; then
            echo -e "Average response time: ${BLUE}${avg_time}ms${NC}"
        fi
    else
        echo -e "${RED}✗ FAILED: Host $host is unreachable${NC}"
        return 1
    fi
}

# Function to test multiple common hosts
test_common_hosts() {
    local hosts=("8.8.8.8" "1.1.1.1" "google.com" "cloudflare.com")
    echo -e "${BLUE}=== Testing Common Hosts ===${NC}"
    
    for host in "${hosts[@]}"; do
        echo -e "\nTesting ${YELLOW}$host${NC}..."
        if ping -c 1 -W "$TIMEOUT" "$host" >/dev/null 2>&1; then
            echo -e "${GREEN}✓ $host is reachable${NC}"
        else
            echo -e "${RED}✗ $host is unreachable${NC}"
        fi
    done
}

# Main function
main() {
    local host="${1:-$DEFAULT_HOST}"
    local count="${2:-$DEFAULT_COUNT}"
    
    # Validate inputs
    if [[ "$count" =~ ^[0-9]+$ ]] && [ "$count" -gt 0 ] && [ "$count" -le 100 ]; then
        :
    else
        echo -e "${RED}Error: Count must be a number between 1 and 100${NC}" >&2
        exit 1
    fi
    
    # Check for help flag
    case "$host" in
        -h|--help)
            usage
            ;;
    esac
    
    validate_host "$host"
    
    # Perform ping test
    if ping_test "$host" "$count"; then
        echo -e "\n${GREEN}Ping test completed successfully${NC}"
        
        # Offer to test common hosts if custom host was used
        if [ "$host" != "$DEFAULT_HOST" ]; then
            echo ""
            read -p "Test common hosts as well? (y/N): " -r
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                echo ""
                test_common_hosts
            fi
        fi
    else
        echo -e "\n${RED}Ping test failed${NC}"
        echo -e "${YELLOW}Suggestions:${NC}"
        echo "1. Check your internet connection"
        echo "2. Verify the host address is correct"
        echo "3. Check if firewall is blocking ping"
        echo "4. Try testing with common hosts:"
        test_common_hosts
        exit 1
    fi
}

# Run main function with all arguments
main "$@"
