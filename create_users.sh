#!/bin/bash
LOG_FILE="/var/log/user_management.log"
PASSWORD_FILE="/var/secure/user_passwords.txt"
USER_FILE="$1"
# Check if the user file is provided
if [ -z "$USER_FILE" ]; then
    echo "Usage: $0 <name-of-text-file>"
    exit 1
fi
# Create necessary directories and files with sudo
sudo mkdir -p /var/secure
sudo touch "$LOG_FILE"
sudo touch "$PASSWORD_FILE"
sudo chmod 600 "$PASSWORD_FILE"
# Function to log messages with a timestamp
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | sudo tee -a "$LOG_FILE"
}
# Ensure the file ends with a newline
echo "" >> "$USER_FILE"
while IFS=';' read -r username groups; do
    # Remove whitespace
    username=$(echo "$username" | xargs)
    groups=$(echo "$groups" | xargs)
    # Skip empty lines and invalid usernames
    if [ -z "$username" ]; then
        continue
    fi
    # Create personal group for the user
    if ! getent group "$username" &>/dev/null; then
        sudo groupadd "$username"
        if [ $? -eq 0 ]; then
            log "Personal group $username created."
        else
            log "Failed to create personal group $username."
            continue
        fi
    fi
    # Create user with personal group
    if id "$username" &>/dev/null; then
        log "User $username already exists."
    else
        sudo useradd -m -s /bin/bash -g "$username" "$username"
        if [ $? -eq 0 ]; then
            log "User $username created."
            # Create a random password
            password=$(openssl rand -base64 12)
            echo "$username:$password" | sudo chpasswd
            if [ $? -eq 0 ]; then
                echo "$username,$password" | sudo tee -a "$PASSWORD_FILE"
                log "Password set for user $username."
            else
                log "Failed to set password for user $username."
            fi
            # Set up home directory permissions
            sudo chown "$username:$username" "/home/$username"
            sudo chmod 700 "/home/$username"
        else
            log "Failed to create user $username."
            continue
        fi
    fi
    # Add user to specified groups
    IFS=',' read -r -a group_array <<< "$groups"
    for group in "${group_array[@]}"; do
        group=$(echo "$group" | xargs)
        if ! getent group "$group" &>/dev/null; then
            sudo groupadd "$group"
            if [ $? -eq 0 ]; then
                log "Group $group created."
            else
                log "Failed to create group $group."
                continue
            fi
        fi
        sudo usermod -aG "$group" "$username"
        if [ $? -eq 0 ]; then
            log "User $username added to group $group."
        else
            log "Failed to add user $username to group $group."
        fi
    done
done < "$USER_FILE"
log "User creation process completed."
