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
SSH_SYSTEM_BACKUP="/usr/local/bin/ssh.system_backup"
ZSHRC="$HOME/.zshrc"

echo "Starting installation process..."

# Ensure the script is run with sudo
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root. Use 'sudo ./install.sh'."
    exit 1
fi

# Create tool directory and backup directory
echo "Creating tool directory and backup directory at $TOOL_DIR..."
mkdir -p "$TOOL_DIR"
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

# Backup ~/.zshrc
if [ -f "$ZSHRC" ]; then
    echo "Backing up $ZSHRC to $BACKUP_DIR/zshrc.bak ..."
    cp "$ZSHRC" "$BACKUP_DIR/zshrc.bak"
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
echo "Installing ssh_register.sh to $MAIN_SCRIPT ..."
cp ssh_register.sh "$MAIN_SCRIPT"
chmod +x "$MAIN_SCRIPT"

# Install uninstall.sh
echo "Installing uninstall.sh to $UNINSTALL_SCRIPT ..."
cp uninstall.sh "$UNINSTALL_SCRIPT"
chmod +x "$UNINSTALL_SCRIPT"

# Backup and handle the Mach-O ssh binary
if [ -f "$SSH_WRAPPER" ] && ! [ -L "$SSH_WRAPPER" ]; then
    echo "Backing up existing Mach-O SSH binary to $SSH_SYSTEM_BACKUP ..."
    mv "$SSH_WRAPPER" "$SSH_SYSTEM_BACKUP"
elif [ -L "$SSH_WRAPPER" ]; then
    echo "Removing existing SSH wrapper symlink ..."
    rm "$SSH_WRAPPER"
fi

# Create custom SSH wrapper
echo "Creating custom SSH wrapper at $SSH_WRAPPER ..."
cat <<EOF >"$SSH_WRAPPER"
#!/usr/bin/env bash
if [[ -z "\$1" ]]; then
    # Call ssh_register if no arguments are provided
    /usr/local/bin/ssh_tool/ssh_register
elif [[ "\$1" == "-l" || "\$1" == "-r" || "\$1" == "-e" || "\$1" == "-uninstall" ]]; then
    /usr/local/bin/ssh_tool/ssh_register "\$@"
else
    /usr/bin/ssh "\$@"
fi
EOF
chmod +x "$SSH_WRAPPER"

# Add autocompletion to ~/.zshrc
if ! grep -q "_ssh_hosts" "$ZSHRC"; then
    echo "Adding Zsh autocompletion snippet to $ZSHRC ..."
    cat <<'EOF' >>"$ZSHRC"

# Ensure compinit is loaded only once
if ! (typeset -f compinit &>/dev/null && command compinit -l &>/dev/null); then
    autoload -Uz compinit
    compinit
fi

# SSH autocompletion for custom script
_ssh_hosts() {
    compadd $(grep -E "^Host" ~/.ssh/config | awk '{print $2}')
}
compdef _ssh_hosts ssh
EOF
fi

# Reload Zsh configuration
echo "Reloading Zsh configuration..."
if [[ -f "$ZSHRC" ]]; then
    source "$ZSHRC"
else
    echo "Warning: .zshrc file not found. Please reload your terminal manually."
fi

echo "Installation complete!"
