#!/bin/sh

# Function to log date and time messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] - $1"
}

# Create directory /personal_scripts if it doesn't exist
log_message "Creating /personal_scripts directory if it doesn't exist"
mkdir -p /personal_scripts
log_message "✔ Directory /personal_scripts created or already exists"

# Download the bridge-ip-track.sh script
log_message "Downloading bridge-ip-track.sh script"
wget -O /personal_scripts/bridge-ip-track.sh https://raw.githubusercontent.com/dr-dolomite/BridgeIPTracker/refs/heads/main/bridge-ip-track.sh

# Check if the file is downloaded
if [ -f /personal_scripts/bridge-ip-track.sh ]; then
    log_message "✔ Script downloaded successfully"
else
    log_message "✘ Script download failed"
    exit 1
fi

# Make the script executable
log_message "Making script executable"
chmod +x /personal_scripts/bridge-ip-track.sh
log_message "✔ Script made executable"

# Add the script to /etc/rc.local to run on boot
log_message "Updating /etc/rc.local to auto-run the script on boot"
if grep -q "/personal_scripts/bridge-ip-track.sh &" /etc/rc.local; then
    log_message "✔ Script already added to /etc/rc.local"
else
    sed -i -e '$i \ /personal_scripts/bridge-ip-track.sh &\n' /etc/rc.local
    log_message "✔ Script added to /etc/rc.local"
fi

# Run the bridge-ip-track.sh script
log_message "Running the bridge-ip-track.sh script"
sh /personal_scripts/bridge-ip-track.sh &
log_message "✔ bridge-ip-track.sh script started"

log_message "Setup complete!"