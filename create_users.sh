#!/bin/bash

LOG_FILE="/var/log/user_management.log"
PASSWORD_FILE="/var/secure/user_passwords.txt"
USER_FILE="$1"

# Function to log messages with a timestamp
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | sudo tee -a "$LOG_FILE"
}

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
    if ! dscl . -read "/Groups/$username" &>/dev/null; then
        sudo dscl . -create "/Groups/$username" &>/dev/null
        if [ $? -eq 0 ]; then
            log_message "Personal group for $username created."
        else
            log_message "Failed to create personal group $username."
            continue
        fi
    else
        log_message "Personal group for $username already exists."
    fi

    # Create user with personal group
    if ! dscl . -read "/Users/$username" &>/dev/null; then
        password=$(openssl rand -base64 12)
        sudo dscl . -create "/Users/$username" &>/dev/null
        sudo dscl . -create "/Users/$username" UserShell "/bin/bash" &>/dev/null
        sudo dscl . -create "/Users/$username" NFSHomeDirectory "/Users/$username" &>/dev/null
        sudo dscl . -create "/Users/$username" PrimaryGroupID "$(dscl . -read /Groups/staff PrimaryGroupID | awk '{print $2}')" &>/dev/null
        sudo dscl . -passwd "/Users/$username" "$password" &>/dev/null
        sudo mkdir -p "/Users/$username" &>/dev/null
        sudo chown "$username:staff" "/Users/$username" &>/dev/null
        sudo chmod 755 "/Users/$username" &>/dev/null
        
        log_message "User with username $username created."
        log_message "Password set for user with username $username."
        echo "$username,$password" | sudo tee -a "$PASSWORD_FILE" &>/dev/null
        echo "$username,$password"
    else
        log_message "User with username $username already exists."
    fi

    # Add user to specified groups
    IFS=',' read -r -a group_array <<< "$groups"
    for group in "${group_array[@]}"; do
        group=$(echo "$group" | xargs)
        if ! dscl . -read "/Groups/$group" &>/dev/null; then
            sudo dscl . -create "/Groups/$group" &>/dev/null
            if [ $? -eq 0 ]; then
                log_message "Group $group created."
            else
                log_message "Failed to create group $group."
                continue
            fi
        fi
        sudo dseditgroup -o edit -a "$username" -t user "$group" &>/dev/null
        if [ $? -eq 0 ]; then
            log_message "User with username $username added to group $group."
        else
            log_message "Failed to add user $username to group $group."
        fi
    done

done < "$USER_FILE"

log_message "User creation process completed."
