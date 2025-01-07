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

    # Remove from ~/.ssh/config
    if grep -q "Host $host" "$CONFIG_FILE"; then
        sed -i '' "/Host $host/,+2d" "$CONFIG_FILE"
        echo "Removed $host from $CONFIG_FILE."
    else
        echo "Host $host not found in $CONFIG_FILE."
    fi

    # Remove from known_hosts
    ssh-keygen -R "$host" >/dev/null 2>&1
    echo "Removed $host from known_hosts."
}

function register_host() {
    local host=$1
    local username=$2

    # --- Removed the ping check to avoid Tailscale or partial DNS issues ---
    # If you still want to check connectivity, uncomment these lines:
    # if ! ping -c 1 -W 1 "$host" >/dev/null 2>&1; then
    #     echo "Error: Host $host is not reachable."
    #     exit 1
    # fi

    # Check if the host is already in config
    if grep -q "Host $host" "$CONFIG_FILE" || grep -q "Hostname $host" "$CONFIG_FILE"; then
        echo "$host is already configured. Using existing settings."
        ssh "$host" || handle_host_key_change "$host"
        return
    fi

    read -rp "Do you want to register this host ($host)? (y/n): " register_decision
    if [[ "$register_decision" == "y" ]]; then

        # Prompt for username if not provided
        if [ -z "$username" ]; then
            read -rp "Enter the username for $host: " username
        fi

        # Ask if host & hostname are the same
        read -rp "Should 'host' and 'hostname' be the same? (y/n): " same_host
        if [[ $same_host == "n" ]]; then
            read -rp "Enter the Host (alias): " host_alias
            read -rp "Enter the Hostname (IP or domain): " hostname
        else
            host_alias=$host
            hostname=$host
        fi

        if [[ -z "$host_alias" || -z "$hostname" ]]; then
            echo "Error: Invalid alias or hostname. Exiting."
            exit 1
        fi

        # Install SSH key
        echo "Installing SSH key on $hostname..."
        ssh-copy-id -- "$username@$hostname"
        if [ $? -ne 0 ]; then
            echo "Error: Failed to install SSH key on $hostname."
            read -rp "Do you want to retry with -f to force the installation? (y/n): " force
            if [[ $force == "y" ]]; then
                ssh-copy-id -f -- "$username@$hostname"
                if [ $? -ne 0 ]; then
                    echo "Error: Forced key installation also failed. Exiting."
                    exit 1
                fi
            else
                echo "Key installation skipped. Exiting."
                exit 1
            fi
        fi

        # Append config
        echo -e "\nHost $host_alias\n    Hostname $hostname\n    User $username" >> "$CONFIG_FILE"
        if ! grep -q "Host $host_alias" "$CONFIG_FILE"; then
            echo "Error: Failed to append $host_alias to $CONFIG_FILE. Exiting."
            exit 1
        fi

        echo "Host $host_alias saved in $CONFIG_FILE."
        ssh "$host_alias"

    else
        # If user says no, fallback to normal SSH
        echo "Skipping host registration. Connecting via normal SSH..."
        exec /usr/bin/ssh "$host"
    fi
}

function handle_host_key_change() {
    local host=$1
    echo "Warning: The host key for $host has changed."
    echo "This could indicate a security risk (e.g., a man-in-the-middle attack)."
    read -rp "Do you want to update the host key? (y/n) " update_key
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
    echo "| Flag       | Function         | Description                 |"
    echo "--------------------------------------------"
    echo "| -r         | remove_host      | Remove a host               |"
    echo "| -l         | list_hosts       | List hosts                  |"
    echo "| -e         | edit_config_file | Edit config file            |"
    echo "| <host>     | register_host    | Register a host             |"
    echo "| -uninstall | uninstall_tool   | Uninstall and restore       |"
    echo "--------------------------------------------"
    echo "Run with no arguments to see this help table."
}

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
        # If no arguments, show help
        if [ -z "$1" ]; then
            show_help_table
            exit 0
        fi
        # Otherwise, assume $1 is the hostname
        register_host "$1" "$2"
        ;;
esac
