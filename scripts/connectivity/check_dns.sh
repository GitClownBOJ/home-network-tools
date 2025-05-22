#!/bin/bash

# check_dns.sh - Test DNS resolution and performance
# Usage: ./check_dns.sh [domain] [dns_server]

set -euo pipefail

# Default values
DEFAULT_DOMAIN="google.com"
DEFAULT_DNS_SERVERS=("8.8.8.8" "1.1.1.1" "208.67.222.222")
TIMEOUT=5

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to display usage
usage() {
    echo "Usage: $0 [domain] [dns_server]"
    echo "  domain:     Domain to resolve (default: $DEFAULT_DOMAIN)"
    echo "  dns_server: Specific DNS server to test (optional)"
    echo ""
    echo "Examples:"
    echo "  $0                        # Test google.com with multiple DNS servers"
    echo "  $0 github.com             # Test github.com with multiple DNS servers"
    echo "  $0 example.com 8.8.8.8    # Test example.com with Google DNS"
    echo ""
    echo "Features:"
    echo "  • Tests multiple DNS servers"
    echo "  • Measures resolution time"
    echo "  • Shows A, AAAA, and MX records"
    echo "  • Detects DNS hijacking"
    exit 1
}

# Function to check if required tools are available
check_requirements() {
    local missing_tools=()
    
    for tool in dig nslookup host; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -eq 3 ]; then
        echo -e "${RED}Error: No DNS lookup tools found (dig, nslookup, or host)${NC}" >&2
        echo "Please install dnsutils (Ubuntu/Debian) or bind-utils (RHEL/CentOS)" >&2
        exit 1
    fi
}

# Function to resolve using dig
resolve_with_dig() {
    local domain=$1
    local server=$2
    local record_type=${3:-A}
    
    if command -v dig >/dev/null 2>&1; then
        dig +time="$TIMEOUT" +tries=1 @"$server" "$domain" "$record_type" +short 2>/dev/null
    fi
}

# Function to resolve using nslookup
resolve_with_nslookup() {
    local domain=$1
    local server=$2
    
    if command -v nslookup >/dev/null 2>&1; then
        timeout "$TIMEOUT" nslookup "$domain" "$server" 2>/dev/null | grep -A 10 "Name:" | grep "Address:" | cut -d' ' -f2 | head -5
    fi
}

# Function to resolve using host
resolve_with_host() {
    local domain=$1
    local server=$2
    
    if command -v host >/dev/null 2>&1; then
        timeout "$TIMEOUT" host "$domain" "$server" 2>/dev/null | grep "has address" | cut -d' ' -f4
    fi
}

# Function to measure DNS resolution time
measure_dns_time() {
    local domain=$1
    local server=$2
    
    if command -v dig >/dev/null 2>&1; then
        local result
        result=$(dig +time="$TIMEOUT" +tries=1 @"$server" "$domain" 2>/dev/null | grep "Query time:")
        if [ -n "$result" ]; then
            echo "$result" | grep -o '[0-9]* msec' | grep -o '[0-9]*'
        fi
    fi
}

# Function to get current DNS servers
get_current_dns() {
    local dns_servers=()
    
    # Try different methods to get DNS servers
    if [ -f /etc/resolv.conf ]; then
        while IFS= read -r line; do
            if [[ $line =~ ^nameserver[[:space:]]+([0-9.]+) ]]; then
                dns_servers+=("${BASH_REMATCH[1]}")
            fi
        done < /etc/resolv.conf
    fi
    
    # Fallback for macOS
    if [ ${#dns_servers[@]} -eq 0 ] && command -v scutil >/dev/null 2>&1; then
        mapfile -t dns_servers < <(scutil --dns | grep 'nameserver\[[0-9]*\]' | awk '{print $3}')
    fi
    
    printf '%s\n' "${dns_servers[@]}"
}

# Function to test a single DNS server
test_dns_server() {
    local domain=$1
    local server=$2
    local server_name=$3
    
    echo -e "${CYAN}Testing $server_name ($server)${NC}"
    
    # Test A record
    local start_time=$(date +%s%N)
    local result
    
    if command -v dig >/dev/null 2>&1; then
        result=$(resolve_with_dig "$domain" "$server" "A")
    elif command -v nslookup >/dev/null 2>&1; then
        result=$(resolve_with_nslookup "$domain" "$server")
    else
        result=$(resolve_with_host "$domain" "$server")
    fi
    
    local end_time=$(date +%s%N)
    local duration=$(( (end_time - start_time) / 1000000 ))
    
    if [ -n "$result" ]; then
        echo -e "  ${GREEN}✓ Success${NC} (${duration}ms)"
        echo "$result" | while read -r ip; do
            if [ -n "$ip" ]; then
                echo -e "    A: ${BLUE}$ip${NC}"
            fi
        done
        
        # Test AAAA record (IPv6)
        if command -v dig >/dev/null 2>&1; then
            local ipv6_result
            ipv6_result=$(resolve_with_dig "$domain" "$server" "AAAA")
            if [ -n "$ipv6_result" ]; then
                echo "$ipv6_result" | while read -r ipv6; do
                    if [ -n "$ipv6" ]; then
                        echo -e "    AAAA: ${BLUE}$ipv6${NC}"
                    fi
                done
            fi
        fi
        
        return 0
    else
        echo -e "  ${RED}✗ Failed${NC} (timeout or error)"
        return 1
    fi
}

# Function to test multiple DNS servers
test_multiple_dns() {
    local domain=$1
    local servers=("${@:2}")
    local successful=0
    local total=${#servers[@]}
    
    echo -e "${BLUE}=== DNS Resolution Test ===${NC}"
    echo -e "Domain: ${YELLOW}$domain${NC}"
    echo -e "Testing ${total} DNS servers...\n"
    
    for server in "${servers[@]}"; do
        local server_name
        case $server in
            8.8.8.8) server_name="Google DNS" ;;
            8.8.4.4) server_name="Google DNS Alt" ;;
            1.1.1.1) server_name="Cloudflare DNS" ;;
            1.0.0.1) server_name="Cloudflare DNS Alt" ;;
            208.67.222.222) server_name="OpenDNS" ;;
            208.67.220.220) server_name="OpenDNS Alt" ;;
            *) server_name="Custom DNS" ;;
        esac
        
        if test_dns_server "$domain" "$server" "$server_name"; then
            ((successful++))
        fi
        echo ""
    done
    
    echo -e "${BLUE}=== Summary ===${NC}"
    echo -e "Successful: ${GREEN}$successful${NC}/$total"
    
    if [ $successful -eq 0 ]; then
        echo -e "${RED}All DNS servers failed${NC}"
        return 1
    elif [ $successful -lt $total ]; then
        echo -e "${YELLOW}Some DNS servers failed${NC}"
        return 2
    else
        echo -e "${GREEN}All DNS servers working${NC}"
        return 0
    fi
}

# Function to show current DNS configuration
show_dns_config() {
    echo -e "${BLUE}=== Current DNS Configuration ===${NC}"
    
    local current_dns
    mapfile -t current_dns < <(get_current_dns)
    
    if [ ${#current_dns[@]} -gt 0 ]; then
        for dns in "${current_dns[@]}"; do
            echo -e "Nameserver: ${YELLOW}$dns${NC}"
        done
    else
        echo -e "${YELLOW}Could not determine current DNS servers${NC}"
    fi
    echo ""
}

# Function to perform comprehensive DNS test
comprehensive_test() {
    local domain=$1
    
    show_dns_config
    
    # Test with current DNS servers
    local current_dns
    mapfile -t current_dns < <(get_current_dns)
    
    if [ ${#current_dns[@]} -gt 0 ]; then
        echo -e "${BLUE}=== Testing Current DNS Servers ===${NC}"
        test_multiple_dns "$domain" "${current_dns[@]}"
        echo ""
    fi
    
    # Test with popular public DNS servers
    echo -e "${BLUE}=== Testing Public DNS Servers ===${NC}"
    test_multiple_dns "$domain" "${DEFAULT_DNS_SERVERS[@]}"
    
    # Additional DNS record tests
    if command -v dig >/dev/null 2>&1; then
        echo -e "\n${BLUE}=== Additional Record Types ===${NC}"
        
        # MX records
        local mx_result
        mx_result=$(dig +short MX "$domain" 2>/dev/null)
        if [ -n "$mx_result" ]; then
            echo -e "${CYAN}MX Records:${NC}"
            echo "$mx_result" | while read -r mx; do
                echo -e "  ${BLUE}$mx${NC}"
            done
        fi
        
        # NS records
        local ns_result
        ns_result=$(dig +short NS "$domain" 2>/dev/null)
        if [ -n "$ns_result" ]; then
            echo -e "${CYAN}NS Records:${NC}"
            echo "$ns_result" | while read -r ns; do
                echo -e "  ${BLUE}$ns${NC}"
            done
        fi
    fi
}

# Main function
main() {
    local domain="${1:-$DEFAULT_DOMAIN}"
    local specific_dns="$2"
    
    # Check for help flag
    case "${domain:-}" in
        -h|--help)
            usage
            ;;
    esac
    
    check_requirements
    
    if [ -n "$specific_dns" ]; then
        # Test specific DNS server
        echo -e "${BLUE}=== Testing Specific DNS Server ===${NC}"
        test_multiple_dns "$domain" "$specific_dns"
    else
        # Comprehensive test
        comprehensive_test "$domain"
    fi
    
    echo -e "\n${GREEN}DNS test completed${NC}"
}

# Run main function with all arguments
main "$@"
