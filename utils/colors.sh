#!/bin/bash

# utils/colors.sh - Color definitions for terminal output

# Check if output is to a terminal
if [[ -t 1 ]]; then
    # Regular colors
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    PURPLE='\033[0;35m'
    CYAN='\033[0;36m'
    WHITE='\033[0;37m'
    GRAY='\033[0;90m'
    
    # Bold colors
    BOLD_RED='\033[1;31m'
    BOLD_GREEN='\033[1;32m'
    BOLD_YELLOW='\033[1;33m'
    BOLD_BLUE='\033[1;34m'
    BOLD_PURPLE='\033[1;35m'
    BOLD_CYAN='\033[1;36m'
    BOLD_WHITE='\033[1;37m'
    
    # Background colors
    BG_RED='\033[41m'
    BG_GREEN='\033[42m'
    BG_YELLOW='\033[43m'
    BG_BLUE='\033[44m'
    BG_PURPLE='\033[45m'
    BG_CYAN='\033[46m'
    BG_WHITE='\033[47m'
    
    # Special formatting
    BOLD='\033[1m'
    DIM='\033[2m'
    UNDERLINE='\033[4m'
    BLINK='\033[5m'
    REVERSE='\033[7m'
    HIDDEN='\033[8m'
    
    # Reset
    NC='\033[0m' # No Color
else
    # No colors for non-terminal output
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    PURPLE=''
    CYAN=''
    WHITE=''
    GRAY=''
    BOLD_RED=''
    BOLD_GREEN=''
    BOLD_YELLOW=''
    BOLD_BLUE=''
    BOLD_PURPLE=''
    BOLD_CYAN=''
    BOLD_WHITE=''
    BG_RED=''
    BG_GREEN=''
    BG_YELLOW=''
    BG_BLUE=''
    BG_PURPLE=''
    BG_CYAN=''
    BG_WHITE=''
    BOLD=''
    DIM=''
    UNDERLINE=''
    BLINK=''
    REVERSE=''
    HIDDEN=''
    NC=''
fi

# Status colors
SUCCESS="$GREEN"
WARNING="$YELLOW"
ERROR="$RED"
INFO="$BLUE"

# Export color variables
export RED GREEN YELLOW BLUE PURPLE CYAN WHITE GRAY
export BOLD_RED BOLD_GREEN BOLD_YELLOW BOLD_BLUE BOLD_PURPLE BOLD_CYAN BOLD_WHITE
export BG_RED BG_GREEN BG_YELLOW BG_BLUE BG_PURPLE BG_CYAN BG_WHITE
export BOLD DIM UNDERLINE BLINK REVERSE HIDDEN NC
export SUCCESS WARNING ERROR INFO
