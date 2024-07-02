#!/bin/bash

log_file="/var/log/user_management.log"
password_file="/var/secure/user_passwords.txt"

# Log message function
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$log_file"
}

# Check for root
if [ "$(id -u)" -ne 0 ]; then
    log_message "Error: Script must be run as root"
    exit 1
fi

# Check if input file is provided
if [ -z "$1" ]; then
    log_message "Error: No input file provided"
    exit 1
fi
input_file="$1"

# Check if input file exists
if [ ! -f "$input_file" ]; then
    log_message "Input file not found: $input_file"
    exit 1
fi

log_message "Processing input file: $input_file"

# Ensure log file and password file exist and have correct permissions
sudo mkdir -p /var/secure
sudo touch "$log_file"
sudo touch "$password_file"
sudo chmod 600 "$password_file"

while IFS=';' read -r username groups; do
    if [ -z "$username" ] || [ -z "$groups" ]; then
        log_message "Skipping invalid line: $username;$groups"
        continue
    fi

    log_message "Processing line: $username;$groups"

    # Handle multiple groups separated by commas
    IFS=',' read -r -a group_array <<< "$groups"
    
    # Create groups if they do not exist
    for group in "${group_array[@]}"; do
        if ! dscl . -read "/Groups/$group" &>/dev/null; then
            if dscl . -create "/Groups/$group"; then
                log_message "$(date '+%Y-%m-%d %H:%M:%S') - Personal group $group created."
            else
                log_message "Failed to create group: $group"
                continue
            fi
        else
            log_message "Group already exists: $group"
        fi
    done

    # Create user if not exists and handle personal group
    if ! dscl . -read "/Users/$username" &>/dev/null; then
        password=$(openssl rand -base64 12)
        if dscl . -create "/Users/$username"; then
            log_message "$(date '+%Y-%m-%d %H:%M:%S') - User $username created."
            dscl . -create "/Users/$username" UserShell "/bin/bash"
            dscl . -create "/Users/$username" NFSHomeDirectory "/Users/$username"
            mkdir -p "/Users/$username"
            #chown "$username:staff" "/Users/$username"
            chmod 755 "/Users/$username"
            dscl . -passwd "/Users/$username" "$password"
            echo "$username,$password" | sudo tee -a "$password_file"
            sudo chmod 600 "$password_file"
            log_message "$(date '+%Y-%m-%d %H:%M:%S') - Password set for user $username."
        else
            log_message "Failed to create user: $username"
            continue
        fi
    else
        log_message "User already exists: $username"
    fi

    # Create personal group for the user if not exists
    if ! dscl . -read "/Groups/$username" &>/dev/null; then
        if dscl . -create "/Groups/$username"; then
            log_message "$(date '+%Y-%m-%d %H:%M:%S') - Personal group $username created."
            dscl . -append "/Groups/$username" GroupMembership "$username"
        else
            log_message "Failed to create personal group: $username"
            continue
        fi
    else
        log_message "Personal group already exists: $username"
    fi

    # Add user to groups
    for group in "${group_array[@]}"; do
        if dscl . -append "/Groups/$group" GroupMembership "$username"; then
            log_message "$(date '+%Y-%m-%d %H:%M:%S') - User $username added to group $group."
        else
            log_message "Failed to add user $username to group $group"
        fi
    done
done < "$input_file"

log_message "$(date '+%Y-%m-%d %H:%M:%S') - User creation process completed"
