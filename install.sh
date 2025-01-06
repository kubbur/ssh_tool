#!/usr/bin/env bash

# Install script for macOS
set -e

INSTALL_PATH="/usr/local/bin"
SCRIPT_TARGET="$INSTALL_PATH/ssh_register"
SSH_WRAPPER="$INSTALL_PATH/ssh"
ZSHRC="$HOME/.zshrc"
CONFIG_FILE="$HOME/.ssh/config"
BACKUP_DIR="$HOME/.ssh/backups"
KNOWN_HOSTS="$HOME/.ssh/known_hosts"

echo "Starting installation process..."

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Backup known_hosts
if [ -f "$KNOWN_HOSTS" ]; then
    echo "Backing up known_hosts to $BACKUP_DIR/known_hosts.bak ..."
    cp "$KNOWN_HOSTS" "$BACKUP_DIR/known_hosts.bak"
fi

# Backup ~/.ssh/config
if [ -f "$CONFIG_FILE" ]; then
    echo "Backing up $CONFIG_FILE to $BACKUP_DIR/config.bak ..."
    cp "$CONFIG_FILE" "$BACKUP_DIR/config.bak"
fi

# Add recommended lines to ~/.ssh/config
if ! grep -q "AddKeysToAgent yes" "$CONFIG_FILE" 2>/dev/null; then
    echo "Adding recommended Host * lines to $CONFIG_FILE ..."
    cat <<EOF >>"$CONFIG_FILE"

Host *
    AddKeysToAgent yes
    IdentityFile ~/.ssh/id_rsa
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

EOF
fi

# Install ssh_register.sh
echo "Installing ssh_register.sh to $SCRIPT_TARGET ..."
sudo cp ssh_register.sh "$SCRIPT_TARGET"
sudo chmod +x "$SCRIPT_TARGET"

# Backup /usr/local/bin/ssh if it exists
if [ -f "$SSH_WRAPPER" ]; then
    echo "Backing up existing ssh wrapper to /usr/local/bin/ssh.bak ..."
    sudo cp "$SSH_WRAPPER" "$SSH_WRAPPER.bak"
fi

# Create custom ssh wrapper
echo "Creating custom ssh wrapper at $SSH_WRAPPER ..."
sudo bash -c "cat <<EOF >$SSH_WRAPPER
#!/usr/bin/env bash
if [[ \"\$1\" == \"-l\" || \"\$1\" == \"-r\" || \"\$1\" == \"-e\" ]]; then
    $SCRIPT_TARGET \"\$@\"
else
    /usr/bin/ssh \"\$@\"
fi
EOF"
sudo chmod +x "$SSH_WRAPPER"

# Add autocompletion to ~/.zshrc
if ! grep -q "_ssh_hosts" "$ZSHRC"; then
    echo "Adding Zsh autocompletion snippet to $ZSHRC ..."
    cat <<'EOF' >>"$ZSHRC"

# SSH autocompletion for custom script
_ssh_hosts() {
    compadd $(grep -E "^Host" ~/.ssh/config | awk '{print $2}')
}
compdef _ssh_hosts ssh

autoload -Uz compinit
compinit

EOF
fi

# Reload Zsh configuration
echo "Reloading Zsh configuration..."
source "$ZSHRC"

echo "Installation complete!"
