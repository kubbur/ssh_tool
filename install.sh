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

# Create custom SSH wrapper that checks ~/.ssh/config for the host:
echo "Creating custom SSH wrapper at $SSH_WRAPPER ..."
cat <<'EOF' >"$SSH_WRAPPER"
#!/usr/bin/env bash

CONFIG_FILE="$HOME/.ssh/config"
SSH_TOOL_SCRIPT="/usr/local/bin/ssh_tool/ssh_register"

host="$1"

# 1) If no arguments, run our tool (shows help)
if [[ -z "$host" ]]; then
    exec "$SSH_TOOL_SCRIPT"
fi

# 2) If recognized flags (-l, -r, -e, -uninstall), run our tool
case "$host" in
    -l|-r|-e|-uninstall)
        exec "$SSH_TOOL_SCRIPT" "$@"
        ;;
esac

# 3) Otherwise, check if this "host" is in ~/.ssh/config
#    (We look for lines like "Host spainscale", "Host spainscale ")
if grep -qE "^Host[[:space:]]+$host(\$|[[:space:]])" "$CONFIG_FILE" 2>/dev/null; then
    # Already in ~/.ssh/config → call system SSH
    exec /usr/bin/ssh "$@"
else
    # Not in ~/.ssh/config → call our custom script for interactive registration
    exec "$SSH_TOOL_SCRIPT" "$@"
fi
EOF

chmod +x "$SSH_WRAPPER"

# Add autocompletion snippet if user is truly in Zsh
# (Some minimal shells can cause "autoload: command not found")
if [ -f "$ZSHRC" ]; then
    # A quick test: is $SHELL or $ZSH_VERSION set to zsh?
    if [[ "$SHELL" == *"zsh" ]] || [[ -n "$ZSH_VERSION" ]]; then
        if ! grep -q "_ssh_hosts" "$ZSHRC"; then
            echo "Adding Zsh autocompletion snippet to $ZSHRC ..."
            cat <<'ACEOF' >>"$ZSHRC"

# SSH Tool autocompletion for custom script
if type compinit &>/dev/null; then
    # Ensure compinit is loaded
    autoload -Uz compinit
    compinit

    _ssh_hosts() {
        compadd $(grep -E "^Host" ~/.ssh/config | awk '{print $2}')
    }
    compdef _ssh_hosts ssh
else
    echo "Warning: 'compinit' not found. Skipping zsh autocompletion setup."
fi

ACEOF
        fi
    else
        echo "It appears you're not using Zsh, or \$ZSH_VERSION is not set."
        echo "Skipping Zsh autocompletion snippet."
    fi
fi

# Reload Zsh configuration
echo "Reloading Zsh configuration..."
if [[ -f "$ZSHRC" ]]; then
    # We'll try sourcing, but if user isn't in a true Zsh environment, it's harmless
    source "$ZSHRC" || true
else
    echo "Warning: .zshrc file not found. Please reload your terminal manually."
fi

echo "Installation complete!"
