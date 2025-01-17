#!/usr/bin/env bash

# Uninstall script for macOS
set -e

TOOL_DIR="/usr/local/bin/ssh_tool"
MAIN_SCRIPT="$TOOL_DIR/ssh_register"
UNINSTALL_SCRIPT="$TOOL_DIR/uninstall.sh"
BACKUP_DIR="$TOOL_DIR/backups"
CONFIG_FILE="$HOME/.ssh/config"
KNOWN_HOSTS="$HOME/.ssh/known_hosts"
ZSHRC="$HOME/.zshrc"
SSH_WRAPPER="/usr/local/bin/ssh"
SSH_BACKUP="/usr/local/bin/ssh.system_backup"

echo "Starting uninstallation process..."

# Restore backup of ~/.ssh/config
if [ -f "$BACKUP_DIR/config.bak" ]; then
    echo "Restoring backup of $CONFIG_FILE ..."
    cp "$BACKUP_DIR/config.bak" "$CONFIG_FILE"
else
    echo "No backup found for $CONFIG_FILE. Skipping."
fi

# Restore backup of known_hosts
if [ -f "$BACKUP_DIR/known_hosts.bak" ]; then
    echo "Restoring backup of $KNOWN_HOSTS ..."
    cp "$BACKUP_DIR/known_hosts.bak" "$KNOWN_HOSTS"
else
    echo "No backup found for $KNOWN_HOSTS. Skipping."
fi

# Restore backup of ~/.zshrc
if [ -f "$BACKUP_DIR/zshrc.bak" ]; then
    echo "Restoring backup of $ZSHRC ..."
    cp "$BACKUP_DIR/zshrc.bak" "$ZSHRC"
else
    echo "No backup found for $ZSHRC. Attempting to clean modifications manually."
    # Remove the autocompletion snippet from ~/.zshrc
    if grep -q "_ssh_hosts" "$ZSHRC"; then
        echo "Removing Zsh autocompletion snippet from $ZSHRC ..."
        sed -i '' '/# SSH autocompletion for custom script/,+7d' "$ZSHRC"
    else
        echo "Zsh autocompletion snippet not found in $ZSHRC. Skipping."
    fi
fi

# Remove the main script
if [ -f "$MAIN_SCRIPT" ]; then
    echo "Removing $MAIN_SCRIPT ..."
    sudo rm "$MAIN_SCRIPT"
else
    echo "$MAIN_SCRIPT not found. Skipping."
fi

# Remove the uninstall script
if [ -f "$UNINSTALL_SCRIPT" ]; then
    echo "Removing $UNINSTALL_SCRIPT ..."
    sudo rm "$UNINSTALL_SCRIPT"
else
    echo "$UNINSTALL_SCRIPT not found. Skipping."
fi

# Restore or remove the SSH wrapper
if [ -f "$SSH_BACKUP" ]; then
    echo "Restoring original Mach-O ssh binary ..."
    sudo mv "$SSH_BACKUP" "$SSH_WRAPPER"
    sudo chmod +x "$SSH_WRAPPER"
elif [ -L "$SSH_WRAPPER" ]; then
    echo "SSH wrapper is a symlink. Removing it ..."
    sudo rm "$SSH_WRAPPER"
    echo "Restoring default system SSH..."
    sudo ln -sf /usr/bin/ssh "$SSH_WRAPPER"
else
    echo "No backup or symlink found for SSH. Restoring default system SSH..."
    sudo ln -sf /usr/bin/ssh "$SSH_WRAPPER"
fi

# Remove the tool directory
if [ -d "$TOOL_DIR" ]; then
    echo "Removing tool directory $TOOL_DIR ..."
    sudo rm -rf "$TOOL_DIR"
else
    echo "$TOOL_DIR not found. Skipping."
fi

# Reload Zsh configuration
if [ -f "$ZSHRC" ]; then
    echo "Reloading Zsh configuration..."
    source "$ZSHRC"
else
    echo "Zsh configuration file not found. Skipping reload."
fi

# Verify terminal restoration
if ! command -v ssh &>/dev/null; then
    echo "Error: SSH command is not functioning. Please check manually."
    exit 1
fi

echo "Uninstallation complete!"
