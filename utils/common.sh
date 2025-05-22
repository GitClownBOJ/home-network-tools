#!/bin/bash

# utils/common.sh - Common utility functions for IoT Network Tools
# Source this file in other scripts: source "$(dirname "$0")/../utils/common.sh"

# Get the directory of the current script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_ROOT="$(dirname "$SCRIPT_DIR")"

# Source other utility files
source "$TOOLS_ROOT/utils/colors.sh" 2>/dev/null || true
source "$TOOLS_ROOT/utils/config.sh" 2>/dev/null || true

# Global variables
VERBOSE=false
QUIET=false
JSON_OUTPUT=false
OUTPUT_FILE=""
LOG_DIR="$HOME/.iot-network-tools/logs"
TEMP_DIR="/tmp/iot-network-tools"

# Create necessary directories
mkdir -p "$LOG_DIR" "$TEMP_DIR"

# Logging functions
log_info() {
    local msg="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] INFO: $msg" >> "$LOG_DIR/$(basename "$0" .sh).log"
    if [[ "$QUIET" != "true" ]]; then
        echo -e "${GREEN}[INFO]${NC} $msg"
    fi
}

log_warn() {
    local msg="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] WARN: $msg" >> "$LOG_DIR/$(basename "$0" .sh).log"
    if [[ "$QUIET" != "true" ]]; then
        echo -e "${YELLOW}[WARN]${NC} $msg"
    fi
}

log_error() {
    local msg="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] ERROR: $msg" >> "$LOG_DIR/$(basename "$0" .sh).log"
    echo -e "${RED}[ERROR]${NC} $msg" >&2
}

log_debug() {
    local msg="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    if [[ "$VERBOSE" == "true" ]]; then
        echo "[$timestamp] DEBUG: $msg" >> "$LOG_DIR/$(basename "$0" .sh).log"
        echo -e "${BLUE}[DEBUG]${NC} $msg"
    fi
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check required dependencies
check_dependencies() {
    local deps=("$@")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command_exists "$dep"; then
            missing+=("$dep")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing[*]}"
        log_info "Please install missing dependencies and try again"
        return 1
    fi
    
    return 0
}

# Validate IP address
is_valid_ip() {
    local ip="$1"
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        local IFS='.'
        local -a octets=($ip)
        for octet in "${octets[@]}"; do
            if (( octet > 255 )); then
                return 1
            fi
        done
        return 0
    fi
    return 1
}

# Validate network CIDR
is_valid_cidr() {
    local cidr="$1"
    if [[ $cidr =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$ ]]; then
        local network="${cidr%/*}"
        local prefix="${cidr#*/}"
        if is_valid_ip "$network" && (( prefix >= 0 && prefix <= 32 )); then
            return 0
        fi
    fi
    return 1
}

# Get local network range
get_local_network() {
    local interface=$(ip route | grep default | head -1 | awk '{print $5}')
    local network=$(ip route | grep "$interface" | grep -E '192\.168\.|10\.|172\.' | head -1 | awk '{print $1}')
    echo "$network"
}

# Get default gateway
get_gateway() {
    ip route | grep default | head -1 | awk '{print $3}'
}

# Get local IP address
get_local_ip() {
    local interface=$(ip route | grep default | head -1 | awk '{print $5}')
    ip addr show "$interface" | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1 | head -1
}

# Progress bar function
show_progress() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    
    printf "\r["
    printf "%${filled}s" | tr ' ' '='
    printf "%${empty}s" | tr ' ' '-'
    printf "] %d%% (%d/%d)" "$percentage" "$current" "$total"
}

# Spinner function for long-running operations
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
}

# Format time duration
format_duration() {
    local seconds=$1
    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))
    local secs=$((seconds % 60))
    
    if (( hours > 0 )); then
        printf "%dh %02dm %02ds" $hours $minutes $secs
    elif (( minutes > 0 )); then
        printf "%dm %02ds" $minutes $secs
    else
        printf "%ds" $secs
    fi
}

# JSON output functions
json_start() {
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        echo "{"
    fi
}

json_end() {
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        echo "}"
    fi
}

json_array_start() {
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        echo "  \"$1\": ["
    fi
}

json_array_end() {
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        echo "  ]"
    fi
}

json_object() {
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        echo "    {"
        local first=true
        while [[ $# -gt 0 ]]; do
            if [[ "$first" == "false" ]]; then
                echo ","
            fi
            echo -n "      \"$1\": \"$2\""
            first=false
            shift 2
        done
        echo ""
        echo "    }"
    fi
}

# Save output to file if specified
save_output() {
    local content="$1"
    if [[ -n "$OUTPUT_FILE" ]]; then
        echo "$content" >> "$OUTPUT_FILE"
        log_debug "Output saved to: $OUTPUT_FILE"
    fi
}

# Common argument parsing
parse_common_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -q|--quiet)
                QUIET=true
                shift
                ;;
            -j|--json)
                JSON_OUTPUT=true
                shift
                ;;
            -o|--output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                # Return unrecognized arguments
                break
                ;;
        esac
    done
}

# Network utility functions
ping_host() {
    local host="$1"
    local timeout="${2:-3}"
    local count="${3:-1}"
    
    if command_exists ping; then
        if ping -c "$count" -W "$timeout" "$host" >/dev/null 2>&1; then
            return 0
        fi
    fi
    return 1
}

# Get hostname from IP
get_hostname() {
    local ip="$1"
    local hostname
    
    # Try multiple methods
    hostname=$(nslookup "$ip" 2>/dev/null | grep 'name =' | awk '{print $4}' | sed 's/\.$//')
    if [[ -z "$hostname" ]]; then
        hostname=$(dig -x "$ip" +short 2>/dev/null | sed 's/\.$//')
    fi
    if [[ -z "$hostname" ]]; then
        hostname=$(host "$ip" 2>/dev/null | awk '{print $5}' | sed 's/\.$//')
    fi
    
    echo "${hostname:-unknown}"
}

# Get MAC address from IP (requires root/sudo)
get_mac_address() {
    local ip="$1"
    local mac
    
    # Try ARP table first
    mac=$(arp -n "$ip" 2>/dev/null | grep -E "([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}" | awk '{print $3}')
    
    # If not found, try ip neighbor
    if [[ -z "$mac" ]]; then
        mac=$(ip neighbor show "$ip" 2>/dev/null | grep -E "([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}" | awk '{print $5}')
    fi
    
    echo "${mac:-unknown}"
}

# Cleanup function
cleanup() {
    local exit_code=${1:-0}
    log_debug "Cleaning up temporary files..."
    rm -rf "$TEMP_DIR/$(basename "$0" .sh)"*
    exit "$exit_code"
}

# Set up signal handlers
trap 'cleanup 130' INT
trap 'cleanup 143' TERM

# Export functions that might be used by other scripts
export -f log_info log_warn log_error log_debug
export -f command_exists check_dependencies
export -f is_valid_ip is_valid_cidr
export -f ping_host get_hostname get_mac_address
