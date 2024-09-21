#!/bin/sh

LOG_FILE="/tmp/wan_ip_track.log"
STATUS_FILE="/tmp/wan_status.txt"
CHECK_INTERVAL=30
RETRY_INTERVAL=60
MAX_DOWN_CHECKS=5
MAX_RESTARTS=5          # Maximum restarts before increasing interval
LONG_RETRY_INTERVAL=900 # 15 minutes

# Initialize the restart counter
restart_counter=0

# Wait for the router to fully boot up
sleep 15

# Create a cron job to delete the log file every 3 days at 3:00 AM
if ! grep -q "$LOG_FILE" /etc/crontabs/root; then
    echo "0 3 */3 * * rm $LOG_FILE" >>/etc/crontabs/root
fi

# Function to log messages with a timestamp
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >>"$LOG_FILE"
}

# Function to get the WAN status from ifstatus
get_wan_status() {
    ifstatus wan >"$STATUS_FILE" 2>/dev/null
    if [ $? -ne 0 ]; then
        log "Failed to get WAN status."
        return 1
    fi

    # Check if the interface is up
    local up=$(grep '"up":' "$STATUS_FILE" | awk '{print $2}' | tr -d ',')
    echo $up
}

# Function to get the current IP address of the wan interface using ifstatus
get_wan_ip() {
    local up_status=$(get_wan_status)
    if [ $? -ne 0 ] || [ "$up_status" = "false" ]; then
        log "WAN interface is down or failed to retrieve status."
        return 1
    fi

    # Extract the IP address from the status file
    grep '"address"' "$STATUS_FILE" | awk -F'"' '{print $4}' 2>/dev/null
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
    log "Restarting WAN interface."
    ifconfig eth1 down
    sleep 5
    ifconfig eth1 up
}

log "Script started."
down_checks=0

while true; do
    up_status=$(get_wan_status)
    if [ $? -ne 0 ]; then
        log "Failed to get WAN status. Sleeping before retry."
        sleep $RETRY_INTERVAL
        continue
    fi

    log "Checking WAN interface status."
    log "WAN interface status: $up_status"

    if [ "$up_status" = "false" ]; then
        log "WAN interface is down. Check count: $((down_checks + 1))"
        down_checks=$((down_checks + 1))
        if [ $down_checks -ge $MAX_DOWN_CHECKS ]; then
            log "WAN has been down for $MAX_DOWN_CHECKS checks. Exiting script."
            exit 1
        fi
        sleep $RETRY_INTERVAL
        continue
    else
        down_checks=0

        current_ip=$(get_wan_ip)
        if [ $? -ne 0 ]; then
            log "Error getting WAN IP. Exiting."
            exit 1
        fi

        log "Checking current IP."

        if is_ip_in_range "$current_ip"; then
            log "IP $current_ip is in the range 192.168.*.*."
            log "Private IP detected."

            # Increment restart counter
            restart_counter=$((restart_counter + 1))
            log "Restart counter: $restart_counter"

            # Restart WAN interface
            restart_interface

            log "WAN interface restarted, waiting for IP to potentially change."

            sleep 10

            new_ip=$(get_wan_ip)
            if [ $? -ne 0 ]; then
                log "WAN interface is down after restart. Exiting."
                exit 1
            fi

            if [ "$restart_counter" -ge $MAX_RESTARTS ]; then
                log "Reached maximum restarts ($MAX_RESTARTS). Increasing retry interval to 15 minutes."
                sleep $LONG_RETRY_INTERVAL
            else
                log "Sleeping for $RETRY_INTERVAL seconds."
                sleep $RETRY_INTERVAL
            fi

        else
            log "IP $current_ip is a public IP."

            while true; do
                log "Checking internet access."

                failed_ping_count=0

                while [ $failed_ping_count -lt 5 ]; do
                    ping -c 5 -I eth1 9.9.9.9 >/dev/null
                    if [ $? -ne 0 ]; then
                        failed_ping_count=$((failed_ping_count + 1))
                        log "Ping failed ($failed_ping_count/5)."
                    else
                        log "Internet is accessible."
                        restart_counter=0   # Reset restart counter on successful internet access
                        failed_ping_count=0 # Reset failed ping counter
                        break
                    fi

                    if [ $failed_ping_count -ge 5 ]; then
                        log "Internet is not accessible after 5 failed pings."
                        log "Checking IP again."
                        break
                    fi

                    sleep $CHECK_INTERVAL
                done

                sleep $CHECK_INTERVAL
            done

        fi
    fi

    sleep $CHECK_INTERVAL
done
