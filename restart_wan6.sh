#!/bin/sh

LOG_FILE="/tmp/restart_wan6.log"

# Function to log messages with a timestamp
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Function to restart the wan6 interface
restart_wan6() {
    log "Attempting to restart wan6 interface."
    ifdown wan6
    sleep 3
    ifup wan6
    log "wan6 interface restarted."
}

# Main execution
log "Restart script started."
restart_wan6
log "Restart script completed."