#!/bin/bash

# utils/config.sh - Configuration settings for IoT Network Tools

# Network configuration
DEFAULT_NETWORK="192.168.1.0/24"
DEFAULT_GATEWAY="192.168.1.1"
DNS_SERVERS=("8.8.8.8" "1.1.1.1" "8.8.4.4" "1.0.0.1")

# Timeout settings (in seconds)
PING_TIMEOUT=3
SCAN_TIMEOUT=30
MONITOR_INTERVAL=60
DNS_TIMEOUT=5
HTTP_TIMEOUT=10

# Camera settings
RTSP_TIMEOUT=10
STREAM_TIMEOUT=5
CAM_DISCOVERY_PORTS=(554 8554 80 443 8080 8081 8000)

# Common IoT device ports
IOT_PORTS=(
    80 443 8080 8081 8443    # HTTP/HTTPS
    22 23 21                 # SSH/Telnet/FTP
    53 67 68                 # DNS/DHCP
    123 161 162              # NTP/SNMP
    554 8554                 # RTSP
    1883 8883                # MQTT
    5353                     # mDNS
    1900                     # UPnP
    502 503                  # Modbus
    20000                    # DNP3
)

# Security scan settings
COMMON_PASSWORDS=(
    "admin:admin"
    "admin:password"
    "admin:"
    "root:root"
    "root:admin"
    "root:password"
    "admin:123456"
    "admin:admin123"
    "user:user"
    "guest:guest"
    "test:test"
    "demo:demo"
    "support:support"
    "service:service"
    "administrator:administrator"
)

# WiFi settings
WIFI_INTERFACE="wlan0"
CHANNEL_SCAN_TIME=3
SIGNAL_THRESHOLD=-70

# Monitoring settings
PING_INTERVAL=5
BANDWIDTH_INTERFACE="eth0"
TRAFFIC_CAPTURE_SIZE=1000

# File paths
CONFIG_DIR="$HOME/.iot-network-tools"
CACHE_DIR="$CONFIG_DIR/cache"
RESULTS_DIR="$CONFIG_DIR/results"
DEVICES_FILE="$CONFIG_DIR/known_devices.txt"

# Create directories if they don't exist
mkdir -p "$CONFIG_DIR" "$CACHE_DIR" "$RESULTS_DIR"

# User overrides - source user config if it exists
USER_CONFIG="$CONFIG_DIR/config.sh"
if [[ -f "$USER_CONFIG" ]]; then
    source "$USER_CONFIG"
fi

# Export configuration variables
export DEFAULT_NETWORK DEFAULT_GATEWAY DNS_SERVERS
export PING_TIMEOUT SCAN_TIMEOUT MONITOR_INTERVAL DNS_TIMEOUT HTTP_TIMEOUT
export RTSP_TIMEOUT STREAM_TIMEOUT CAM_DISCOVERY_PORTS
export IOT_PORTS COMMON_PASSWORDS
export WIFI_INTERFACE CHANNEL_SCAN_TIME SIGNAL_THRESHOLD
export PING_INTERVAL BANDWIDTH_INTERFACE TRAFFIC_CAPTURE_SIZE
export CONFIG_DIR CACHE_DIR RESULTS_DIR DEVICES_FILE
