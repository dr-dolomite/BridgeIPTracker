#!/bin/sh

LOG_FILE="/tmp/wan_ip_track.log"
STATUS_FILE="/tmp/wan_status.txt"
CHECK_INTERVAL=30
RETRY_INTERVAL=60
MAX_DOWN_CHECKS=5
RESTART_WAN6_SCRIPT="/personal_script/restart_wan6.sh"
RESTART_WAN6_RUN=false

# Wait for the router to fully boot up
sleep 15

# Function to log messages with a timestamp
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >>"$LOG_FILE"
}

# Function to get the WAN status from ifstatus
get_wan_status() {
    ifstatus wan >"$STATUS_FILE"
    # Check if the interface is up
    local up=$(grep '"up":' "$STATUS_FILE" | awk '{print $2}' | tr -d ',')
    echo $up
}

# Function to get the current IP address of the wan interface using ifstatus
get_wan_ip() {
    local up_status=$(get_wan_status)
    log "Up status: $up_status"

    if [ "$up_status" = "false" ]; then
        log "WAN interface is down when checking IP."
        return 1
    fi

    # Extract the IP address from the status file
    grep '"address"' "$STATUS_FILE" | awk -F'"' '{print $4}'
}

# Function to check if the IP is in the 192.168.*.* range
is_ip_in_range() {
    local ip=$1
    case $ip in
    192.168.*.*) return 0 ;;
    *) return 1 ;;
    esac
}

# Function to restart the specified interface
restart_interface() {
    local interface=$1
    log "Restarting $interface interface."
    ifdown $interface
    sleep 3
    ifup $interface
}

# Function to run the restart_wan6.sh script
run_restart_wan6() {
    if [ "$RESTART_WAN6_RUN" = false ]; then
        log "WAN IP address initiated properly. Running $RESTART_WAN6_SCRIPT."
        sh "$RESTART_WAN6_SCRIPT"
        RESTART_WAN6_RUN=true
    fi
}

log "Script started."
down_checks=0

while true; do
    # Get the WAN status
    up_status=$(get_wan_status)

    log "Checking WAN interface status."
    log "WAN interface status: $up_status"

    if [ "$up_status" = "false" ]; then
        log "WAN interface is down. Check count: $((++down_checks))"
        if [ $down_checks -ge $MAX_DOWN_CHECKS ]; then
            log "WAN has been down for $MAX_DOWN_CHECKS checks. Exiting script."
            exit 1
        fi
        sleep $RETRY_INTERVAL
        continue
    else
        down_checks=0

        # Get the current IP of the wan interface
        current_ip=$(get_wan_ip)

        log "Checking current IP."

        if [ $? -eq 1 ]; then
            log "Error getting WAN IP. Exiting."
            exit 1
        fi

        # Check if the IP is in the 192.168.*.* range
        if is_ip_in_range "$current_ip"; then
            log "IP $current_ip is in the range 192.168.*.*, which is good."

            # Restart the wan interface
            log "Restarting WAN interface."

            restart_interface "wan"

            log "WAN interface restarted, waiting for IP to potentially change."

            # Wait a bit for the IP to potentially change
            sleep 10

            # Check the new IP address
            new_ip=$(get_wan_ip)

            if [ $? -eq 1 ]; then
                log "WAN interface is down after restart. Exiting."
                exit 1
            fi

            log "New IP after restart: $new_ip"

            if [ "$new_ip" != "$current_ip" ]; then
                log "IP changed to $new_ip, continuing monitoring."
            else
                log "IP did not change, still $new_ip. Sleeping for $RETRY_INTERVAL seconds."
                sleep $RETRY_INTERVAL
            fi

        else
            log "IP $current_ip is a public IP."
            # Run the restart_wan6.sh script if the IP is good
            run_restart_wan6

            # Loop to detect internet access
            while true; do
                # Check if the internet is accessible
                log "Checking internet access."
                ping -c 5 9.9.9.9 >/dev/null 2>&1

                # Check if the ping was unsuccessful
                if [ $? -ne 0 ]; then
                    log "Internet is not accessible."
                    log "Checking IP again."
                    # Proceed to main loop
                    break
                else
                    log "Internet is accessible."
                fi

                sleep 15
            done
        fi
    fi

    # Sleep for the check interval before checking again
    sleep $CHECK_INTERVAL
done
