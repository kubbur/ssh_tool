#!/usr/bin/env bash

# Install script for macOS
set -e

TOOL_DIR="/usr/local/bin/ssh_tool"
MAIN_SCRIPT="$TOOL_DIR/ssh_register"
UNINSTALL_SCRIPT="$TOOL_DIR/uninstall.sh"
BACKUP_DIR="$TOOL_DIR/backups"
CONFIG_FILE="$HOME/.ssh/config"
KNOWN_HOSTS="$HOME/.ssh/known_hosts"
SSH_WRAPPER="/usr/local/bin/ssh"
ZSHRC="$HOME/.zshrc"

echo "Starting installation process..."

# Create tool directory and backup directory
sudo mkdir -p "$TOOL_DIR"
sudo mkdir -p "$BACKUP_DIR"

# Backup known_hosts
if [ -f "$KNOWN_HOSTS" ]; then
    echo "Backing up known_hosts to $BACKUP_DIR/known_hosts.bak ..."
    sudo cp "$KNOWN_HOSTS" "$BACKUP_DIR/known_hosts.bak"
fi

# Backup ~/.ssh/config
if [ -f "$CONFIG_FILE" ]; then
    echo "Backing up $CONFIG_FILE to $BACKUP_DIR/config.bak ..."
    sudo cp "$CONFIG_FILE" "$BACKUP_DIR/config.bak"
fi

# Add recommended lines to ~/.ssh/config
if ! grep -q "AddKeysToAgent yes" "$CONFIG_FILE" 2>/dev/null; then
    echo "Adding recommended Host * lines to $CONFIG_FILE ..."
    sudo bash -c "cat <<EOF >>$CONFIG_FILE

Host *
    AddKeysToAgent yes
    IdentityFile ~/.ssh/id_rsa
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

EOF"
fi

# Install ssh_register.sh
echo "Installing ssh_register.sh to $MAIN_SCRIPT ..."
sudo cp ssh_register.sh "$MAIN_SCRIPT"
sudo chmod +x "$MAIN_SCRIPT"

# Install uninstall.sh
echo "Installing uninstall.sh to $UNINSTALL_SCRIPT ..."
sudo cp uninstall.sh "$UNINSTALL_SCRIPT"
sudo chmod +x "$UNINSTALL_SCRIPT"

# Backup /usr/local/bin/ssh if it exists
if [ -f "$SSH_WRAPPER" ]; then
    echo "Backing up existing ssh wrapper to /usr/local/bin/ssh.bak ..."
    sudo cp "$SSH_WRAPPER" "$SSH_WRAPPER.bak"
fi

# Create custom ssh wrapper
echo "Creating custom ssh wrapper at $SSH_WRAPPER ..."
sudo bash -c "cat <<EOF >$SSH_WRAPPER
#!/usr/bin/env bash
if [[ \"\$1\" == \"-l\" || \"\$1\" == \"-r\" || \"\$1\" == \"-e\" || \"\$1\" == \"-uninstall\" ]]; then
    $MAIN_SCRIPT \"\$@\"
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

# Ensure compinit is loaded only once
if ! (typeset -f compinit &>/dev/null && command compinit -l &>/dev/null); then
    autoload -Uz compinit
    compinit
fi

EOF
fi

# Reload Zsh configuration
echo "Reloading Zsh configuration..."
source "$ZSHRC"

echo "Installation complete!"
