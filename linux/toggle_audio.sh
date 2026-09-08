#!/bin/bash

# Get a clean list of all available audio sink names
SINKS=($(pactl list short sinks | awk '{print $2}'))

# Get the name of the currently active default sink
CURRENT_SINK=$(pactl get-default-sink)

# Find the total number of audio devices found
NUM_SINKS=${#SINKS[@]}

# Loop through the list to find the active one and switch to the next device
for i in "${!SINKS[@]}"; do
    if [ "${SINKS[$i]}" = "$CURRENT_SINK" ]; then
        # Calculate next index (loops back to 0 if at the end of the list)
        NEXT_INDEX=$(( (i + 1) % NUM_SINKS ))
        
        # Set the next device as default
        pactl set-default-sink "${SINKS[$NEXT_INDEX]}"
        break
    fi
done


