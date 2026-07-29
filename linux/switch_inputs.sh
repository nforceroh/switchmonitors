#!/bin/bash

# Default values
MONITOR_ARG="monitor2"
ACTION="CYCLE"

# Parse arguments if provided
if [ ! -z "$1" ]; then MONITOR_ARG=$(echo "$1" | tr '[:upper:]' '[:lower:]'); fi
if [ ! -z "$2" ]; then ACTION=$(echo "$2" | tr '[:upper:]' '[:upper:]'); fi

# -------------------------------------------------------------
# HARDWARE I2C BUS MAPPING
# Tied directly to your GPU physical buses from ddcutil detect
# -------------------------------------------------------------
declare -A MONITOR_MAP
MONITOR_MAP[monitor4]=6   # AOC Q32G1WG4  (/dev/i2c-6)
MONITOR_MAP[monitor2]=8   # GBT M32UC     (/dev/i2c-8)
MONITOR_MAP[monitor1]=9   # DELL S3221QS  (/dev/i2c-9)
MONITOR_MAP[monitor3]=10  # DELL S3221QS  (/dev/i2c-10)

# Resolve the monitor bus number
if [[ -n "${MONITOR_MAP[$MONITOR_ARG]}" ]]; then
    BUS_NUM=${MONITOR_MAP[$MONITOR_ARG]}
elif [[ "$MONITOR_ARG" =~ ^[0-9]+$ ]]; then
    BUS_NUM=$MONITOR_ARG
else
    echo "Error: Unknown monitor '$MONITOR_ARG'"
    exit 1
fi

VCP_CODE="0x60"

# Global ddcutil tuning flags for problematic hardware (like Gigabyte scalers)
# Added --maxtries, --noverify, and disabled dynamic sleep tracking
DDC_FLAGS="--bus=$BUS_NUM --force-slave-address --noverify --disable-dynamic-sleep --sleep-multiplier=3 --maxtries=3,3,3"

# Function to get current input value robustly
get_current_input() {
    local output
    output=$(ddcutil getvcp $VCP_CODE $DDC_FLAGS 2>/dev/null)
    
    if [ -z "$output" ]; then
        echo "ERROR"
        return
    fi
    
    # Extract hex value (looks for sl=0xXX or value 0xXX) using regex
    if [[ "$output" =~ (0x[0-9a-fA-F]+) ]]; then
        echo "${BASH_REMATCH}" | tr '[:upper:]' '[:lower:]'
    else
        echo "ERROR"
    fi
}

# Function to switch input
set_input() {
    local val=$1
    echo "Switching Monitor on Bus $BUS_NUM to value $val..."
    ddcutil setvcp $VCP_CODE "$val" $DDC_FLAGS
}

# Handle specific actions
case "$ACTION" in
    "DP")
        set_input "0x0f" # 15
        ;;
    "HDMI1")
        set_input "0x11" # 17
        ;;
    "HDMI2")
        set_input "0x12" # 18
        ;;
    "CYCLE")
        CURRENT_HEX=$(get_current_input)
        
        if [ "$CURRENT_HEX" = "ERROR" ] || [ -z "$CURRENT_HEX" ]; then
            echo "Warning: I2C read timed out on Bus $BUS_NUM. Pushing fallback command..."
            set_input "0x0f"
            exit 0
        fi

        # Strip any high-byte multi-channel offsets if present (e.g., 0x0f0f -> 0x0f)
        if [ ${#CURRENT_HEX} -gt 4 ]; then
            CURRENT_HEX="0x${CURRENT_HEX: -2}"
        fi

        echo "Current monitor input detected as: $CURRENT_HEX"

        case "$CURRENT_HEX" in
            "0x0f") # DP (15) -> Switch to HDMI1
                set_input "0x11"
                ;;
            "0x11"|"0x10") # HDMI1 (17 or 16) -> Switch to HDMI2
                set_input "0x12"
                ;;
            *) # Default fallback back to DP
                set_input "0x0f"
                ;;
        esac
        ;;
    *)
        echo "Unknown Action: '$ACTION'. Use 'CYCLE', 'DP', 'HDMI1', or 'HDMI2'."
        exit 1
        ;;
esac
