#!/bin/bash

# Paths
CONFIG_FILE="$HOME/.ssh/config"
TOOL_DIR="/usr/local/bin/ssh_tool"
UNINSTALL_SCRIPT="$TOOL_DIR/uninstall.sh"

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

    # Remove the host from ~/.ssh/config
    if grep -q "Host $host" "$CONFIG_FILE"; then
        sed -i '' "/Host $host/,+2d" "$CONFIG_FILE"
        echo "Removed $host from $CONFIG_FILE."
    else
        echo "Host $host not found in $CONFIG_FILE."
    fi

    # Remove the host from known_hosts
    ssh-keygen -R "$host" >/dev/null 2>&1
    echo "Removed $host from known_hosts."
}

function register_host() {
    local host=$1
    local username=$2

    # Check if the host is reachable
    ping -c 1 -W 1 "$host" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "Error: Host $host is not reachable."
        exit 1
    fi

    # Check if the host is already configured
    if grep -q "Host $host" "$CONFIG_FILE" || grep -q "Hostname $host" "$CONFIG_FILE"; then
        echo "$host is already configured. Using existing settings."
        ssh "$host" || handle_host_key_change "$host"
        return
    fi

    read -p "Do you want to register this host? (y/n) " register
    if [[ $register == "y" ]]; then
        # Prompt for username if not provided
        if [ -z "$username" ]; then
            read -p "Enter the username for $host: " username
        fi

        # Determine if host and hostname should differ
        read -p "Should 'host' and 'hostname' be the same? (y/n) " same_host
        if [[ $same_host == "n" ]]; then
            read -p "Enter the Host (e.g., an alias): " host_alias
            read -p "Enter the Hostname (e.g., IP or domain): " hostname
        else
            host_alias=$host
            hostname=$host
        fi

        echo "Installing SSH key on $hostname..."
        ssh-copy-id "$username@$hostname"
        if [ $? -ne 0 ]; then
            echo "Error: Failed to install SSH key on $hostname."
            read -p "Do you want to retry with -f to force the installation? (y/n) " force
            if [[ $force == "y" ]]; then
                ssh-copy-id -f "$username@$hostname"
                if [ $? -ne 0 ]; then
                    echo "Error: Forced key installation also failed. Exiting."
                    exit 1
                fi
            else
                echo "Key installation skipped. Exiting."
                exit 1
            fi
        fi

        echo -e "\nHost $host_alias\n    Hostname $hostname\n    User $username" >> "$CONFIG_FILE"
        echo "Host registered as $host_alias."
        echo "You can now login using: ssh $host_alias"

        # Attempt login
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

function uninstall_tool() {
    echo "Starting the uninstallation process..."
    if [ ! -f "$UNINSTALL_SCRIPT" ]; then
        echo "Error: Uninstall script not found at $UNINSTALL_SCRIPT."
        exit 1
    fi
    bash "$UNINSTALL_SCRIPT"
    if [ $? -eq 0 ]; then
        echo "Uninstallation completed successfully."
    else
        echo "Uninstallation encountered an error. Please check manually."
    fi
    exit 0
}

function show_help_table() {
    echo "SSH Tool for macOS - A Tribute to the Default SSH Utility"
    echo "This is not the default SSH utility. For the original SSH, simply uninstall or disable this tool."
    echo "GitHub Repository: https://github.com/kubbur/ssh_tool"
    echo
    echo "Available Commands:"
    echo "--------------------------------------------"
    echo "| Flag       | Function       | Description                |"
    echo "--------------------------------------------"
    echo "| -r         | remove_host    | Remove a host              |"
    echo "| -l         | list_hosts     | List hosts                 |"
    echo "| -e         | edit_config_file | Edit config file          |"
    echo "| <host>     | register_host  | Register a host            |"
    echo "| -uninstall | uninstall_tool | Uninstall and restore backups|"
    echo "--------------------------------------------"
    echo "Run with no arguments to see this help table."
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
    -uninstall)
        uninstall_tool
        ;;
    *)
        if [ -z "$1" ]; then
            show_help_table
            exit 0
        fi
        register_host "$1" "$2"
        ;;
esac
