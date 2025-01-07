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

# 1) Create tool directory and backup directory
echo "Creating tool directory and backup directory at $TOOL_DIR..."
mkdir -p "$TOOL_DIR"
mkdir -p "$BACKUP_DIR"

# 2) Backup known_hosts
if [ -f "$KNOWN_HOSTS" ]; then
    echo "Backing up known_hosts to $BACKUP_DIR/known_hosts.bak ..."
    cp "$KNOWN_HOSTS" "$BACKUP_DIR/known_hosts.bak"
fi

# 3) Backup ~/.ssh/config
if [ -f "$CONFIG_FILE" ]; then
    echo "Backing up $CONFIG_FILE to $BACKUP_DIR/config.bak ..."
    cp "$CONFIG_FILE" "$BACKUP_DIR/config.bak"
fi

# 4) Backup ~/.zshrc
if [ -f "$ZSHRC" ]; then
    echo "Backing up $ZSHRC to $BACKUP_DIR/zshrc.bak ..."
    cp "$ZSHRC" "$BACKUP_DIR/zshrc.bak"
fi

# 5) Append recommended lines to ~/.ssh/config (if not already there)
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

# 6) Install ssh_register.sh
echo "Installing ssh_register.sh to $MAIN_SCRIPT ..."
cp ssh_register.sh "$MAIN_SCRIPT"
chmod +x "$MAIN_SCRIPT"

# 7) Install uninstall.sh
echo "Installing uninstall.sh to $UNINSTALL_SCRIPT ..."
cp uninstall.sh "$UNINSTALL_SCRIPT"
chmod +x "$UNINSTALL_SCRIPT"

# 8) Backup and handle the Mach-O SSH binary
if [ -f "$SSH_WRAPPER" ] && ! [ -L "$SSH_WRAPPER" ]; then
    echo "Backing up existing Mach-O SSH binary to $SSH_SYSTEM_BACKUP ..."
    mv "$SSH_WRAPPER" "$SSH_SYSTEM_BACKUP"
elif [ -L "$SSH_WRAPPER" ]; then
    echo "Removing existing SSH wrapper symlink ..."
    rm "$SSH_WRAPPER"
fi

# 9) Create custom SSH wrapper
#    The wrapper checks if the host is in ~/.ssh/config. If not, it calls ssh_register.
echo "Creating custom SSH wrapper at $SSH_WRAPPER ..."
cat <<'EOF' >"$SSH_WRAPPER"
#!/usr/bin/env bash

CONFIG_FILE="$HOME/.ssh/config"
SSH_TOOL_SCRIPT="/usr/local/bin/ssh_tool/ssh_register"

host="$1"

# If no arguments, show custom script help
if [[ -z "$host" ]]; then
    exec "$SSH_TOOL_SCRIPT"
fi

# If recognized flags (-l, -r, -e, -uninstall), go to ssh_register
case "$host" in
    -l|-r|-e|-uninstall)
        exec "$SSH_TOOL_SCRIPT" "$@"
        ;;
esac

# Otherwise, check if "host" is in ~/.ssh/config
if grep -qE "^Host[[:space:]]+$host(\$|[[:space:]])" "$CONFIG_FILE" 2>/dev/null; then
    # Host is already configured → real SSH
    exec /usr/bin/ssh "$@"
else
    # Not in ~/.ssh/config → call the register script
    exec "$SSH_TOOL_SCRIPT" "$@"
fi
EOF
chmod +x "$SSH_WRAPPER"

# 10) Force-add Zsh completion snippet on macOS, removing the compinit check
if [ -f "$ZSHRC" ]; then
    if ! grep -q "_ssh_hosts" "$ZSHRC"; then
        echo "Adding Zsh autocompletion snippet to $ZSHRC ..."
        cat <<'ACEOF' >>"$ZSHRC"

# --- SSH Tool autocompletion snippet ---
autoload -Uz compinit 2>/dev/null || true
compinit 2>/dev/null || true

_ssh_hosts() {
    compadd $(grep -E "^Host" ~/.ssh/config | awk '{print $2}')
}
compdef _ssh_hosts ssh
# --- end of SSH Tool snippet ---

ACEOF
    fi
fi

# 11) Reload Zsh configuration
echo "Reloading Zsh configuration..."
if [[ -f "$ZSHRC" ]]; then
    # Sourcing .zshrc can throw harmless errors if you're not truly in zsh
    source "$ZSHRC" || true
else
    echo "Warning: $ZSHRC file not found. Please reload your terminal manually."
fi

echo "Installation complete!"
