#!/bin/sh

# Set the log directory
log_directory="/mnt/RUS-HDD/ping_logs"
log_directory2="/tmp/mountd/disk1_part1/ping_logs"

Check if the log directory exists then set the log directory to the existing one
if [ -d "$log_directory1" ]; then
    log_directory="$log_directory1"
elif [ -d "$log_directory2" ]; then
    log_directory="$log_directory2"
else
    # If the log directory does not exist, create it
    mkdir -p "$log_directory1"
    log_directory="$log_directory1"
fi

while true; do
    # Get the current date and time
    current_date=$(date +"%m%d%y")
    current_time=$(date +"%Y-%m-%d %H:%M:%S")

    # Set the log file name based on the current date
    log_file="$log_directory/${current_date}.log"

    # Ping 9.9.9.9 for 5 packets
    if ping -c 5 -I eth1 9.9.9.9 >/dev/null; then
        # If the ping is successful, log the availability
        echo "$current_time Internet is available" >>"$log_file"
    else
        # If the ping fails, log the unavailability
        echo "$current_time Internet is not available" >>"$log_file"
    fi

    # Sleep for 60 seconds before repeating
    sleep 60
done