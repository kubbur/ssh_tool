# ssh_tool


# SSH Register Utility for macOS

## Overview
This script provides a streamlined way to manage SSH hosts on macOS. It includes functionality for registering, removing, listing, and editing SSH configurations with added convenience features like Zsh autocompletion and backups.

## Features
- **Host Registration**: Automatically adds hosts to `~/.ssh/config` and installs SSH keys for passwordless login.
- **Host Removal**: Removes hosts from `~/.ssh/config`, deletes associated keys from `~/.ssh/authorized_keys` on the remote host, and clears `known_hosts`.
- **Host Listing**: Lists all registered SSH hosts.
- **Host Configuration Editing**: Opens the SSH configuration file in `nano` for quick editing.
- **Zsh Autocompletion**: Autocompletes SSH hostnames directly in the terminal.
- **Backups**: Automatically backs up modified files (`known_hosts`, `~/.ssh/config`) during installation.

## Installation
Run the `install.sh` script to install the utility and make it accessible as the `ssh` command in your terminal.

### Steps:
1. Clone the repository:
   \``bash
   git clone <repository_url>
   cd <repository_directory>
   \``

2. Run the installation script:
   \``bash
   ./install.sh
   \``

3. Reload your terminal environment:
   \``bash
   source ~/.zshrc
   \``

4. Start using the tool! For example:
   \``bash
   ssh -l   # List registered hosts
   ssh -r <host>   # Remove a host
   ssh <host>   # Connect to or register a host
   \``

## Usage
The script integrates directly with the `ssh` command.

### Commands:
- **Register a host**:
  \``bash
  ssh <host> [username]
  \``
  If the host isn't registered, the script will guide you through the process.

- **Remove a host**:
  \``bash
  ssh -r <host>
  \``
  Deletes the host's entry from `~/.ssh/config`, removes its key from `authorized_keys` on the remote host, and clears it from `known_hosts`.

- **List registered hosts**:
  \``bash
  ssh -l
  \``

- **Edit the configuration file**:
  \``bash
  ssh -e
  \``
  Opens `~/.ssh/config` in `nano` for manual adjustments.

### Autocompletion:
Zsh autocompletion is enabled for hostnames in `~/.ssh/config`. Type `ssh <partial_host>` and press `Tab` to autocomplete.

## Uninstallation
Run the `uninstall.sh` script to remove the utility and restore original files.

### Steps:
1. Navigate to the repository directory:
   \``bash
   cd <repository_directory>
   \``

2. Run the uninstallation script:
   \``bash
   ./uninstall.sh
   \``

3. Confirm restoration:
   - Check `~/.ssh/config` and `known_hosts` for backups in `~/.ssh/backups`.

## Notes
- The utility modifies the SSH behavior on your system. If you encounter issues, you can always restore the backups or uninstall the tool.
- Designed specifically for macOS environments using `zsh`.

## Contributing
Feel free to fork the repository and submit pull requests. For bugs or feature requests, open an issue.

## License
This project is licensed under the MIT License. See `LICENSE` for details.
