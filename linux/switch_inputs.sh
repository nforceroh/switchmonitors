#!/bin/bash

# Default values
MONITOR_ARG="monitor2"
ACTION="CYCLE"

# Parse arguments if provided
if [ ! -z "$1" ]; then MONITOR_ARG=$(echo "$1" | tr '[:upper:]' '[:lower:]'); fi
if [ ! -z "$2" ]; then ACTION=$(echo "$2" | tr '[:upper:]' '[:upper:]'); fi

# -------------------------------------------------------------
# HARDWARE IDENTITY MAPPING
# Monitors are matched by serial number (or binary serial, for
# panels that report a blank string serial) instead of a fixed
# I2C bus number, since bus numbers can shift across reboots /
# replugs. Resolved to a live bus number below via ddcutil detect.
# -------------------------------------------------------------
declare -A MONITOR_SERIAL
MONITOR_SERIAL[monitor4]="0x000003fe"    # AOC Q32G1WG4  (no string serial; binary serial used instead)
MONITOR_SERIAL[monitor2]="23510B005459"  # GBT M32UC
MONITOR_SERIAL[monitor1]="36WY6N3"       # DELL S3221QS
MONITOR_SERIAL[monitor3]="375Y6N3"       # DELL S3221QS

# Resolve a monitor id (per MONITOR_SERIAL above) to its current I2C bus number
resolve_bus_by_serial() {
    local target="$1"
    ddcutil detect --verbose 2>/dev/null | awk -v target="$target" '
        /^Display [0-9]+/ {
            if (bus != "" && (serial == target || binserial == target)) print bus
            bus=""; serial=""; binserial=""
        }
        /I2C bus:/ {
            line = $0
            sub(/.*i2c-/, "", line)
            gsub(/[^0-9]/, "", line)
            bus = line
        }
        /Serial number:/ {
            line = $0
            sub(/.*Serial number:[ \t]*/, "", line)
            serial = line
        }
        /Binary serial number:/ {
            match($0, /0x[0-9a-fA-F]+/)
            binserial = substr($0, RSTART, RLENGTH)
        }
        END {
            if (bus != "" && (serial == target || binserial == target)) print bus
        }
    '
}

# Resolve the monitor bus number
if [[ -n "${MONITOR_SERIAL[$MONITOR_ARG]}" ]]; then
    BUS_NUM=$(resolve_bus_by_serial "${MONITOR_SERIAL[$MONITOR_ARG]}")
    if [[ -z "$BUS_NUM" ]]; then
        echo "Error: Could not find a connected monitor matching '$MONITOR_ARG' (serial ${MONITOR_SERIAL[$MONITOR_ARG]}). Is it plugged in?"
        exit 1
    fi
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