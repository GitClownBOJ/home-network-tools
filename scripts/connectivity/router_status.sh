#!/bin/bash

# router_status.sh - Check router/gateway connectivity and status
# Usage: ./router_status.sh [gateway_ip]

set -euo pipefail

# Configuration
TIMEOUT=5
PING_COUNT=4

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Function to display usage
usage() {
    echo "Usage: $0 [gateway_ip]"
    echo ""
    echo "Options:"
    echo "  gateway_ip    Specific gateway IP to test (optional)"
    echo "  -h, --help    Show this help"
    echo ""
    echo "Features:"
    echo "  • Auto-detects default gateway"
    echo "  • Tests gateway connectivity"
    echo "  • Shows network interface information"
    echo "  • Displays routing table"
    echo "  • Tests multiple gateway IPs if available"
    echo "  • Port scan on common router services"
    echo ""
    echo "Examples:"
    echo "  $0                    # Test default gateway"
    echo "  $0 192.168.1.1        # Test specific gateway"
    exit 0
}

# Function to log messages
log() {
    local level=$1
    shift
    local message="$*"
    
    case $level in
        ERROR)   echo -e "${RED}[ERROR]${NC} $message" >&2 ;;
        SUCCESS) echo -e "${GREEN}[SUCCESS]${NC} $message" ;;
        WARNING) echo -e "${YELLOW}[WARNING]${NC} $message" ;;
        INFO)    echo -e "${BLUE}[INFO]${NC} $message" ;;
        DEBUG)   echo -e "${PURPLE}[DEBUG]${NC} $message" ;;
    esac
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to get default gateway
get_default_gateway() {
    local gateways=()
    
    # Try different methods to get gateway
    if command_exists ip; then
        # Modern Linux
        while IFS= read -r gateway; do
            if [ -n "$gateway" ]; then
                gateways+=("$gateway")
            fi
        done < <(ip route show default | awk '/default via/ {print $3}' | sort -u)
    elif command_exists route; then
        # Traditional route command
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            while IFS= read -r gateway; do
                if [ -n "$gateway" ]; then
                    gateways+=("$gateway")
                fi
            done < <(route -n get default | awk '/gateway:/ {print $2}')
        else
            # Linux
            while IFS= read -r gateway; do
                if [ -n "$gateway" ]; then
                    gateways+=("$gateway")
                fi
            done < <(route -n | awk '/^0\.0\.0\.0/ {print $2}' | sort -u)
        fi
    elif command_exists netstat; then
        # Fallback to netstat
        while IFS= read -r gateway; do
            if [ -n "$gateway" ]; then
                gateways+=("$gateway")
            fi
        done < <(netstat -rn | awk '/^0\.0\.0\.0|^default/ {print $2}' | sort -u)
    fi
    
    printf '%s\n' "${gateways[@]}"
}

# Function to get network interface information
show_network_interfaces() {
    echo -e "${CYAN}=== Network Interfaces ===${NC}"
    
    if command_exists ip; then
        # Show active interfaces with IP addresses
        ip addr show | grep -E '^[0-9]+:|inet ' | while IFS= read -r line; do
            if [[ $line =~ ^[0-9]+: ]]; then
                # Interface line
                local interface
                interface=$(echo "$line" | awk -F': ' '{print $2}' | awk '{print $1}')
                local status
                status=$(echo "$line" | grep -o '<[^>]*>' | tr -d '<>')
                
                if [[ "$status" == *"UP"* ]] && [[ "$interface" != "lo" ]]; then
                    echo -e "${GREEN}Interface: $interface ($status)${NC}"
                fi
            elif [[ $line =~ inet\ [0-9] ]]; then
                # IP address line
                local ip netmask
                ip=$(echo "$line" | awk '{print $2}' | cut -d'/' -f1)
                netmask=$(echo "$line" | awk '{print $2}' | cut -d'/' -f2)
                echo -e "  IP: ${BLUE}$ip/$netmask${NC}"
            fi
        done
    elif command_exists ifconfig; then
        # Fallback to ifconfig
        ifconfig | grep -E '^[a-zA-Z]|inet ' | while IFS= read -r line; do
            if [[ $line =~ ^[a-zA-Z] ]]; then
                local interface
                interface=$(echo "$line" | awk '{print $1}' | tr -d ':')
                if [[ "$interface" != "lo" ]] && [[ "$line" == *"UP"* ]]; then
                    echo -e "${GREEN}Interface: $interface${NC}"
                fi
            elif [[ $line =~ inet\ [0-9] ]]; then
                local ip
                ip=$(echo "$line" | awk '{print $2}' | sed 's/addr://')
                echo -e "  IP: ${BLUE}$ip${NC}"
            fi
        done
    else
        log WARNING "No network interface commands available"
    fi
    echo ""
}

# Function to show routing table
show_routing_table() {
    echo -e "${CYAN}=== Routing Table ===${NC}"
    
    if command_exists ip; then
        ip route show | head -10
    elif command_exists route; then
        route -n | head -10
    elif command_exists netstat; then
        netstat -rn | head -10
    else
        log WARNING "No routing commands available"
    fi
    echo ""
}

# Function to test gateway connectivity
test_gateway_connectivity() {
    local gateway=$1
    local gateway_name=${2:-"Gateway"}
    
    echo -e "${CYAN}=== Testing $gateway_name ($gateway) ===${NC}"
    
    # Basic ping test
    log INFO "Testing connectivity with ping..."
    local ping_result ping_exit_code
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        ping_result=$(ping -c "$PING_COUNT" -W "$((TIMEOUT * 1000))" "$gateway" 2>&1)
    else
        # Linux
        ping_result=$(ping -c "$PING_COUNT" -W "$TIMEOUT" "$gateway" 2>&1)
    fi
    ping_exit_code=$?
    
    if [ $ping_exit_code -eq 0 ]; then
        # Extract statistics
        local packet_loss avg_time
        packet_loss=$(echo "$ping_result" | grep -o '[0-9]*% packet loss' | grep -o '[0-9]*' || echo "0")
        avg_time=$(echo "$ping_result" | grep -o 'avg = [0-9.]*\|Average = [0-9.]*' | grep -o '[0-9.]*' || echo "N/A")
        
        if [ "$packet_loss" = "0" ]; then
            log SUCCESS "✓ Gateway is reachable"
            if [ "$avg_time" != "N/A" ]; then
                log INFO "Average response time: ${avg_time}ms"
            fi
        else
            log WARNING "⚠ ${packet_loss}% packet loss detected"
        fi
    else
        log ERROR "✗ Gateway is unreachable"
        return 1
    fi
    
    # Test common router services
    test_router_services "$gateway"
    
    echo ""
    return 0
}

# Function to test common router services
test_router_services() {
    local gateway=$1
    
    if ! command_exists nc && ! command_exists telnet && ! command_exists nmap; then
        log DEBUG "No port scanning tools available"
        return 0
    fi
    
    log INFO "Testing common router services..."
    
    local common_ports=(
        "22:SSH"
        "23:Telnet"
        "53:DNS"
        "80:HTTP"
        "443:HTTPS"
        "8080:HTTP-Alt"
        "8443:HTTPS-Alt"
    )
    
    local open_ports=()
    
    for port_info in "${common_ports[@]}"; do
        local port service
        port=$(echo "$port_info" | cut -d':' -f1)
        service=$(echo "$port_info" | cut -d':' -f2)
        
        if command_exists nc; then
            # Use netcat
            if timeout 2 nc -z "$gateway" "$port" 2>/dev/null; then
                open_ports+=("$port ($service)")
            fi
        elif command_exists telnet; then
            # Use telnet
            if timeout 2 bash -c "echo '' | telnet $gateway $port" 2>/dev/null | grep -q "Connected"; then
                open_ports+=("$port ($service)")
            fi
        fi
    done
    
    if [ ${#open_ports[@]} -gt 0 ]; then
        log SUCCESS "Open ports found:"
        for port in "${open_ports[@]}"; do
            echo -e "  ${BLUE}$port${NC}"
        done
        
        # Suggest web interface access
        for port in "${open_ports[@]}"; do
            if [[ "$port" == *"HTTP"* ]]; then
                local protocol="http"
                local port_num
                port_num=$(echo "$port" | cut -d' ' -f1)
                
                if [[ "$port" == *"443"* ]] || [[ "$port" == *"HTTPS"* ]]; then
                    protocol="https"
                fi
                
                if [ "$port_num" = "80" ] || [ "$port_num" = "443" ]; then
                    log INFO "Web interface likely available at: ${protocol}://${gateway}"
                else
                    log INFO "Web interface likely available at: ${protocol}://${gateway}:${port_num}"
                fi
                break
            fi
        done
    else
        log WARNING "No common router services detected"
    fi
}

# Function to detect router manufacturer
detect_router_info() {
    local gateway=$1
    
    log INFO "Detecting router information..."
    
    # Try to get MAC address for OUI lookup
    local mac_addr=""
    
    if command_exists arp; then
        mac_addr=$(arp -n "$gateway" 2>/dev/null | awk '/[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}/ {print $3}' | head -1)
    elif command_exists ip; then
        mac_addr=$(ip neigh show "$gateway" 2>/dev/null | awk '{print $5}' | head -1)
    fi
    
    if [ -n "$mac_addr" ] && [[ "$mac_addr" =~ ^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$ ]]; then
        log SUCCESS "MAC Address: $mac_addr"
        
        # Extract OUI (first 3 octets)
        local oui
        oui=$(echo "$mac_addr" | cut -d':' -f1-3 | tr '[:lower:]' '[:upper:]')
        
        # Common router OUI prefixes
        case "$oui" in
            "00:1B:2F"|"00:22:6B"|"00:24:A5") log INFO "Manufacturer: Cisco" ;;
            "00:0F:B5"|"00:15:6D"|"00:18:4D") log INFO "Manufacturer: Netgear" ;;
            "00:14:BF"|"00:21:29"|"00:26:5A") log INFO "Manufacturer: Linksys" ;;
            "00:07:7D"|"00:11:50"|"00:15:05") log INFO "Manufacturer: Belkin" ;;
            "00:03:7F"|"00:0A:F5"|"00:13:10") log INFO "Manufacturer: D-Link" ;;
            "00:1D:7E"|"00:23:CD"|"00:26:82") log INFO "Manufacturer: Asus" ;;
            "00:1C:10"|"00:24:01"|"00:26:B8") log INFO "Manufacturer: TP-Link" ;;
            *) log DEBUG "Unknown manufacturer (OUI: $oui)" ;;
        esac
    fi
    
    # Try HTTP-based detection
    if command_exists curl; then
        local http_title
        http_title=$(timeout 5 curl -s "http://$gateway" 2>/dev/null | grep -i '<title>' | sed 's/<[^>]*>//g' | xargs)
        
        if [ -n "$http_title" ]; then
            log INFO "Web interface title: $http_title"
        fi
    fi
}

# Function to run comprehensive router test
run_comprehensive_test() {
    local specific_gateway="$1"
    
    echo -e "${BLUE}=== Router/Gateway Status Check ===${NC}"
    echo -e "Started: $(date)"
    echo ""
    
    show_network_interfaces
    show_routing_table
    
    local gateways=()
    local test_success=false
    
    if [ -n "$specific_gateway" ]; then
        gateways=("$specific_gateway")
    else
        mapfile -t gateways < <(get_default_gateway)
    fi
    
    if [ ${#gateways[@]} -eq 0 ]; then
        log ERROR "No gateway found - check network configuration"
        echo -e "\n${YELLOW}Troubleshooting suggestions:${NC}"
        echo "1. Check if network interface is up"
        echo "2. Verify DHCP configuration"
        echo "3. Check static route configuration"
        echo "4. Restart network service"
        return 1
    fi
    
    log INFO "Found ${#gateways[@]} gateway(s): ${gateways[*]}"
    echo ""
    
    for i in "${!gateways[@]}"; do
        local gateway="${gateways[$i]}"
        local gateway_name="Gateway $((i + 1))"
        
        if [ ${#gateways[@]} -eq 1 ]; then
            gateway_name="Default Gateway"
        fi
        
        if test_gateway_connectivity "$gateway" "$gateway_name"; then
            test_success=true
            detect_router_info "$gateway"
        fi
    done
    
    echo -e "${CYAN}=== Summary ===${NC}"
    if $test_success; then
        log SUCCESS "Router/Gateway connectivity is working"
        return 0
    else
        log ERROR "Router/Gateway connectivity failed"
        echo -e "\n${YELLOW}Troubleshooting suggestions:${NC}"
        echo "1. Check physical cable connections"
        echo "2. Power cycle the router"
        echo "3. Check for IP conflicts"
        echo "4. Verify router configuration"
        echo "5. Contact network administrator"
        return 1
    fi
}

# Main function
main() {
    local gateway=""
    
    # Parse arguments
    case "${1:-}" in
        -h|--help)
            usage
            ;;
        "")
            # No arguments - use default gateway
            ;;
        *)
            # Validate IP address format
            if [[ "$1" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                gateway="$1"
            else
                log ERROR "Invalid IP address format: $1"
                exit 1
            fi
            ;;
    esac
    
    # Check for ping command
    if ! command_exists ping; then
        log ERROR "ping command is required but not found"
        exit 1
    fi
    
    run_comprehensive_test "$gateway"
}

# Run main function with all arguments
main "$@"
