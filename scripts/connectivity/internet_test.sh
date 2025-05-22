#!/bin/bash

# internet_test.sh - Comprehensive internet connectivity test
# Usage: ./internet_test.sh [options]

set -euo pipefail

# Configuration
TIMEOUT=10
USER_AGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"

# Test endpoints
declare -A TEST_ENDPOINTS=(
    ["Google"]="https://www.google.com"
    ["Cloudflare"]="https://www.cloudflare.com"
    ["GitHub"]="https://api.github.com"
    ["Amazon"]="https://aws.amazon.com"
    ["Microsoft"]="https://www.microsoft.com"
)

declare -A SPEED_TEST_FILES=(
    ["Small (100KB)"]="https://www.google.com/images/branding/googlelogo/2x/googlelogo_color_272x92dp.png"
    ["Medium (1MB)"]="https://httpbin.org/bytes/1048576"
    ["Large (10MB)"]="https://httpbin.org/bytes/10485760"
)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Flags
VERBOSE=false
QUICK=false
SKIP_SPEED=false

# Function to display usage
usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -v, --verbose    Show detailed output"
    echo "  -q, --quick      Quick test (skip some checks)"
    echo "  -s, --skip-speed Skip speed test"
    echo "  -h, --help       Show this help"
    echo ""
    echo "Features:"
    echo "  • Tests basic connectivity"
    echo "  • DNS resolution test"
    echo "  • HTTP/HTTPS connectivity"
    echo "  • Speed test with multiple file sizes"
    echo "  • Latency measurements"
    echo "  • Public IP detection"
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
        DEBUG)   $VERBOSE && echo -e "${PURPLE}[DEBUG]${NC} $message" ;;
    esac
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check basic connectivity
test_basic_connectivity() {
    echo -e "${CYAN}=== Basic Connectivity Test ===${NC}"
    
    local hosts=("8.8.8.8" "1.1.1.1" "208.67.222.222")
    local success_count=0
    
    for host in "${hosts[@]}"; do
        log DEBUG "Testing ping to $host"
        if ping -c 1 -W 5 "$host" >/dev/null 2>&1; then
            log SUCCESS "✓ $host is reachable"
            ((success_count++))
        else
            log ERROR "✗ $host is unreachable"
        fi
    done
    
    if [ $success_count -eq 0 ]; then
        log ERROR "No basic connectivity - check your network connection"
        return 1
    elif [ $success_count -lt ${#hosts[@]} ]; then
        log WARNING "Partial connectivity issues detected"
        return 2
    else
        log SUCCESS "Basic connectivity is working"
        return 0
    fi
}

# Function to test DNS resolution
test_dns_resolution() {
    echo -e "\n${CYAN}=== DNS Resolution Test ===${NC}"
    
    local domains=("google.com" "github.com" "cloudflare.com")
    local success_count=0
    
    for domain in "${domains[@]}"; do
        log DEBUG "Resolving $domain"
        
        local start_time=$(date +%s%N)
        if command_exists dig; then
            if dig +time=5 +tries=1 "$domain" >/dev/null 2>&1; then
                local end_time=$(date +%s%N)
                local duration=$(( (end_time - start_time) / 1000000 ))
                log SUCCESS "✓ $domain resolved (${duration}ms)"
                ((success_count++))
            else
                log ERROR "✗ Failed to resolve $domain"
            fi
        elif command_exists nslookup; then
            if timeout 5 nslookup "$domain" >/dev/null 2>&1; then
                log SUCCESS "✓ $domain resolved"
                ((success_count++))
            else
                log ERROR "✗ Failed to resolve $domain"
            fi
        else
            log WARNING "No DNS tools available (dig/nslookup)"
            break
        fi
    done
    
    if [ $success_count -eq 0 ]; then
        log ERROR "DNS resolution is not working"
        return 1
    elif [ $success_count -lt ${#domains[@]} ]; then
        log WARNING "Some DNS queries failed"
        return 2
    else
        log SUCCESS "DNS resolution is working"
        return 0
    fi
}

# Function to test HTTP/HTTPS connectivity
test_http_connectivity() {
    echo -e "\n${CYAN}=== HTTP/HTTPS Connectivity Test ===${NC}"
    
    local success_count=0
    local total_endpoints=${#TEST_ENDPOINTS[@]}
    
    for name in "${!TEST_ENDPOINTS[@]}"; do
        local url="${TEST_ENDPOINTS[$name]}"
        log DEBUG "Testing HTTP connection to $name ($url)"
        
        local start_time=$(date +%s%N)
        if command_exists curl; then
            local http_code
            http_code=$(curl -s -o /dev/null -w "%{http_code}" \
                           --max-time "$TIMEOUT" \
                           --user-agent "$USER_AGENT" \
                           "$url" 2>/dev/null || echo "000")
            
            local end_time=$(date +%s%N)
            local duration=$(( (end_time - start_time) / 1000000 ))
            
            if [[ "$http_code" =~ ^[23] ]]; then
                log SUCCESS "✓ $name - HTTP $http_code (${duration}ms)"
                ((success_count++))
            else
                log ERROR "✗ $name - HTTP $http_code"
            fi
        elif command_exists wget; then
            if timeout "$TIMEOUT" wget -q --spider "$url" 2>/dev/null; then
                log SUCCESS "✓ $name is accessible"
                ((success_count++))
            else
                log ERROR "✗ $name is not accessible"
            fi
        else
            log WARNING "No HTTP tools available (curl/wget)"
            break
        fi
        
        $QUICK && [ $success_count -gt 2 ] && break
    done
    
    if [ $success_count -eq 0 ]; then
        log ERROR "No HTTP connectivity"
        return 1
    elif [ $success_count -lt $((total_endpoints / 2)) ]; then
        log WARNING "Limited HTTP connectivity"
        return 2
    else
        log SUCCESS "HTTP/HTTPS connectivity is working"
        return 0
    fi
}

# Function to get public IP
get_public_ip() {
    echo -e "\n${CYAN}=== Public IP Detection ===${NC}"
    
    local ip_services=("https://ipinfo.io/ip" "https://icanhazip.com" "https://api.ipify.org")
    
    for service in "${ip_services[@]}"; do
        log DEBUG "Trying to get IP from $service"
        
        if command_exists curl; then
            local ip
            ip=$(curl -s --max-time 5 "$service" 2>/dev/null | tr -d '\n\r' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$')
            
            if [ -n "$ip" ]; then
                log SUCCESS "Public IP: $ip"
                
                # Get additional info if using ipinfo.io
                if [[ "$service" == *"ipinfo.io"* ]] && ! $QUICK; then
                    local location
                    location=$(curl -s --max-time 5 "https://ipinfo.io/$ip/json" 2>/dev/null | \
                              grep -E '"(city|region|country)":' | \
                              sed 's/.*: *"\([^"]*\)".*/\1/' | \
                              paste -sd ',' -)
                    
                    if [ -n "$location" ]; then
                        log INFO "Location: $location"
                    fi
                fi
                return 0
            fi
        fi
    done
    
    log WARNING "Could not determine public IP"
    return 1
}

# Function to test download speed
test_download_speed() {
    echo -e "\n${CYAN}=== Download Speed Test ===${NC}"
    
    if $SKIP_SPEED; then
        log INFO "Speed test skipped"
        return 0
    fi
    
    if ! command_exists curl; then
        log WARNING "curl not available - skipping speed test"
        return 1
    fi
    
    for size_name in "${!SPEED_TEST_FILES[@]}"; do
        local url="${SPEED_TEST_FILES[$size_name]}"
        log DEBUG "Testing download speed with $size_name file"
        
        local start_time=$(date +%s%N)
        local result
        result=$(curl -s -w "%{speed_download}:%{time_total}" \
                     --max-time 30 \
                     -o /dev/null \
                     "$url" 2>/dev/null || echo "0:0")
        
        local end_time=$(date +%s%N)
        local speed_bytes speed_mbps total_time
        
        speed_bytes=$(echo "$result" | cut -d':' -f1 | cut -d'.' -f1)
        total_time=$(echo "$result" | cut -d':' -f2)
        
        if [ "$speed_bytes" -gt 0 ]; then
            speed_mbps=$(echo "scale=2; $speed_bytes * 8 / 1000000" | bc -l 2>/dev/null || echo "0")
            log SUCCESS "$size_name: ${speed_mbps} Mbps (${total_time}s)"
        else
            log ERROR "$size_name: Download failed"
        fi
        
        $QUICK && break
    done
}

# Function to test latency to various servers
test_latency() {
    echo -e "\n${CYAN}=== Latency Test ===${NC}"
    
    local servers=("8.8.8.8" "1.1.1.1" "208.67.222.222")
    local total_latency=0
    local successful_pings=0
    
    for server in "${servers[@]}"; do
        log DEBUG "Testing latency to $server"
        
        local ping_result
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            ping_result=$(ping -c 3 -W 3000 "$server" 2>/dev/null | grep "avg" | cut -d'/' -f5)
        else
            # Linux
            ping_result=$(ping -c 3 -W 3 "$server" 2>/dev/null | grep "avg" | cut -d'/' -f5)
        fi
        
        if [ -n "$ping_result" ]; then
            log SUCCESS "$server: ${ping_result}ms"
            total_latency=$(echo "$total_latency + $ping_result" | bc -l 2>/dev/null || echo "$total_latency")
            ((successful_pings++))
        else
            log ERROR "$server: No response"
        fi
        
        $QUICK && [ $successful_pings -gt 1 ] && break
    done
    
    if [ $successful_pings -gt 0 ]; then
        local avg_latency
        avg_latency=$(echo "scale=1; $total_latency / $successful_pings" | bc -l 2>/dev/null || echo "N/A")
        log INFO "Average latency: ${avg_latency}ms"
    fi
}

# Function to run comprehensive test
run_comprehensive_test() {
    echo -e "${BLUE}=== Internet Connectivity Test ===${NC}"
    echo -e "Started: $(date)"
    echo ""
    
    local test_results=()
    local overall_status="SUCCESS"
    
    # Run tests
    if test_basic_connectivity; then
        test_results+=("Basic Connectivity: PASS")
    else
        test_results+=("Basic Connectivity: FAIL")
        overall_status="FAIL"
    fi
    
    if test_dns_resolution; then
        test_results+=("DNS Resolution: PASS")
    else
        test_results+=("DNS Resolution: FAIL")
        overall_status="FAIL"
    fi
    
    if test_http_connectivity; then
        test_results+=("HTTP/HTTPS: PASS")
    else
        test_results+=("HTTP/HTTPS: FAIL")
        overall_status="FAIL"
    fi
    
    get_public_ip || test_results+=("Public IP: WARNING")
    
    if ! $QUICK; then
        test_latency
        test_download_speed
    fi
    
    # Display summary
    echo -e "\n${CYAN}=== Test Summary ===${NC}"
    for result in "${test_results[@]}"; do
        if [[ "$result" == *"PASS"* ]]; then
            echo -e "${GREEN}✓ $result${NC}"
        elif [[ "$result" == *"FAIL"* ]]; then
            echo -e "${RED}✗ $result${NC}"
        else
            echo -e "${YELLOW}⚠ $result${NC}"
        fi
    done
    
    echo ""
    echo -e "Completed: $(date)"
    
    if [ "$overall_status" = "SUCCESS" ]; then
        echo -e "\n${GREEN}Overall Status: Internet connectivity is working properly${NC}"
        return 0
    else
        echo -e "\n${RED}Overall Status: Internet connectivity issues detected${NC}"
        echo -e "\n${YELLOW}Troubleshooting suggestions:${NC}"
        echo "1. Check physical network connections"
        echo "2. Restart network interface: sudo ifdown eth0 && sudo ifup eth0"
        echo "3. Flush DNS cache: sudo systemctl restart systemd-resolved"
        echo "4. Check firewall settings"
        echo "5. Contact your ISP if issues persist"
        return 1
    fi
}

# Function to parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -q|--quick)
                QUICK=true
                shift
                ;;
            -s|--skip-speed)
                SKIP_SPEED=true
                shift
                ;;
            -h|--help)
                usage
                ;;
            *)
                echo "Unknown option: $1" >&2
                usage
                ;;
        esac
    done
}

# Function to check dependencies
check_dependencies() {
    local missing_tools=()
    local suggested_tools=("ping" "curl" "dig" "bc")
    
    for tool in "${suggested_tools[@]}"; do
        if ! command_exists "$tool"; then
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        log WARNING "Some tools are missing: ${missing_tools[*]}"
        log INFO "For full functionality, install: sudo apt-get install curl dnsutils bc"
    fi
    
    # Check for essential tools
    if ! command_exists ping; then
        log ERROR "ping command is required but not found"
        exit 1
    fi
}

# Main function
main() {
    parse_args "$@"
    check_dependencies
    run_comprehensive_test
}

# Run main function with all arguments
main "$@"
