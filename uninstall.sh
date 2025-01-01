#!/usr/bin/env bash

# Uninstall script for macOS
set -e

INSTALL_PATH="/usr/local/bin"
SCRIPT_TARGET="$INSTALL_PATH/ssh_register"
SSH_WRAPPER="$INSTALL_PATH/ssh"
ZSHRC="$HOME/.zshrc"
CONFIG_FILE="$HOME/.ssh/config"
BACKUP_DIR="$HOME/.ssh/backups"
KNOWN_HOSTS="$HOME/.ssh/known_hosts"

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
    echo "Restoring backup of known_hosts ..."
    cp "$BACKUP_DIR/known_hosts.bak" "$KNOWN_HOSTS"
else
    echo "No backup found for known_hosts. Skipping."
fi

# Remove ssh_register.sh from /usr/local/bin
if [ -f "$SCRIPT_TARGET" ]; then
    echo "Removing $SCRIPT_TARGET ..."
    sudo rm "$SCRIPT_TARGET"
else
    echo "$SCRIPT_TARGET not found. Skipping."
fi

# Restore backup of /usr/local/bin/ssh if it exists
if [ -f "$SSH_WRAPPER.bak" ]; then
    echo "Restoring original ssh from backup ..."
    sudo mv "$SSH_WRAPPER.bak" "$SSH_WRAPPER"
    sudo chmod +x "$SSH_WRAPPER"
elif [ -f "$SSH_WRAPPER" ]; then
    echo "Removing custom ssh wrapper ..."
    sudo rm "$SSH_WRAPPER"
fi

# Remove the autocompletion snippet from ~/.zshrc
if grep -q "_ssh_hosts" "$ZSHRC"; then
    echo "Removing Zsh autocompletion snippet from $ZSHRC ..."
    sed -i '' '/# SSH autocompletion for custom script/,+6d' "$ZSHRC"
else
    echo "Zsh autocompletion snippet not found in $ZSHRC. Skipping."
fi

# Reload Zsh configuration
echo "Reloading Zsh configuration..."
source "$ZSHRC"

echo "Uninstallation complete!"

