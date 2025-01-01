#!/bin/bash

CONFIG_FILE="$HOME/.ssh/config"

function edit_config_file() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "No SSH config file found. Creating it..."
        sudo touch "$CONFIG_FILE"
        sudo chmod 600 "$CONFIG_FILE"
    fi

    echo "Opening SSH config file with sudo..."
    sudo nano "$CONFIG_FILE"
}

function list_hosts() {
    if [ ! -f "$CONFIG_FILE" ] || [ ! -s "$CONFIG_FILE" ]; then
        echo "No registered hosts found in $CONFIG_FILE."
        return
    fi

    echo "Registered hosts:"
    grep -E '^Host ' "$CONFIG_FILE" | awk '{print $2}'
}

function remove_host() {
    local host=$1

    # Retrieve the username and hostname from ~/.ssh/config
    local username
    local hostname
    username=$(grep -A2 "Host $host" "$CONFIG_FILE" | grep "User" | awk '{print $2}')
    hostname=$(grep -A2 "Host $host" "$CONFIG_FILE" | grep "Hostname" | awk '{print $2}')

    if [ -z "$hostname" ]; then
        hostname=$host
    fi

    # Check if the remote host is reachable
    ping -c 1 -W 1 "$hostname" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "Attempting to remove key from remote host ($hostname)..."
        ssh "$username@$hostname" "if [ -f ~/.ssh/authorized_keys ]; then
            grep -v '$(cat ~/.ssh/id_rsa.pub)' ~/.ssh/authorized_keys > ~/.ssh/authorized_keys.tmp && \
            mv ~/.ssh/authorized_keys.tmp ~/.ssh/authorized_keys && \
            echo 'Remote key removed successfully.' || \
            echo 'Failed to remove key from authorized_keys.'
        else
            echo 'No authorized_keys file found on remote host.'
        fi" 2>/dev/null

        if [ $? -ne 0 ]; then
            echo "Failed to connect to $hostname. Please ensure the host is accessible and SSH is configured properly."
        fi
    else
        echo "Remote host $hostname is not reachable. Skipping remote key removal."
    fi

    # Remove the host from ~/.ssh/config
    if grep -q "Host $host" "$CONFIG_FILE"; then
        # On macOS, use sed -i '' for in-place editing
        sed -i '' "/Host $host/,+2d" "$CONFIG_FILE"
        echo "Removed $host from $CONFIG_FILE."
    else
        echo "Host $host not found in $CONFIG_FILE."
    fi

    # Remove the host from known_hosts
    ssh-keygen -R "$host" >/dev/null 2>&1
    ssh-keygen -R "$hostname" >/dev/null 2>&1
    echo "Removed $host and $hostname from known_hosts."
}

function register_host() {
    local host=$1
    local username=$2

    # Check if host is reachable
    ping -c 1 -W 1 "$host" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "Error: Host $host is not reachable."
        exit 1
    fi

    # Check if host is already configured
    if grep -q "Host $host" "$CONFIG_FILE" || grep -q "Hostname $host" "$CONFIG_FILE"; then
        echo "$host is already configured. Using existing settings."
        ssh "$host" || handle_host_key_change "$host"
        return
    fi

    # Ask if user wants to register the host
    read -p "Do you want to register this host? (y/n) " register
    if [[ $register == "y" ]]; then
        # Get username if not provided
        if [ -z "$username" ]; then
            read -p "Enter the username for $host: " username
        fi

        # Ask if host and hostname should be the same
        read -p "Should 'host' and 'hostname' be the same? (y/n) " same_host
        if [[ $same_host == "n" ]]; then
            read -p "Enter the Host (e.g., an alias): " host_alias
            read -p "Enter the Hostname (e.g., IP or domain): " hostname
        else
            host_alias=$host
            hostname=$host
        fi

        # Try to install SSH key
        echo "Installing SSH key on $hostname..."
        ssh-copy-id "$username@$hostname"
        if [ $? -ne 0 ]; then
            echo "Error: Failed to install SSH key on $hostname."
            exit 1
        fi

        # Add host to SSH config
        echo -e "\nHost $host_alias\n    Hostname $hostname\n    User $username" >> "$CONFIG_FILE"
        echo "Host registered as $host_alias."
        echo "You can now login using: ssh $host_alias"

        # Automatically log in
        ssh "$host_alias"
    else
        # Proceed with normal login
        if [ -z "$username" ]; then
            read -p "Enter the username for $host: " username
        fi
        ssh "$username@$host"
    fi
}

function handle_host_key_change() {
    local host=$1
    echo "Warning: The host key for $host has changed."
    echo "This could indicate a security risk (e.g., a man-in-the-middle attack)."
    read -p "Do you want to update the host key? (y/n) " update_key
    if [[ $update_key == "y" ]]; then
        ssh-keygen -R "$host" >/dev/null 2>&1
        echo "Old key removed. Attempting to reconnect and re-register the host..."
        register_host "$host"
    else
        echo "Aborting due to host key mismatch."
        exit 1
    fi
}

# Main flag handler
case "$1" in
    -r)
        if [ -z "$2" ]; then
            echo "Usage: $0 -r <host>"
            exit 1
        fi
        remove_host "$2"
        ;;
    -l)
        list_hosts
        ;;
    -e)
        edit_config_file
        ;;
    *)
        if [ -z "$1" ]; then
            echo "Usage: $0 <host> [username] or $0 -r <host> or $0 -l or $0 -e"
            exit 1
        fi
        register_host "$1" "$2"
        ;;
esac

