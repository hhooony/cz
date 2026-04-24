#!/usr/bin/env bash
# common.sh - Shared functions for backup and restore scripts

error_exit() {
    echo "Error: $1" >&2
    exit 1
}

require_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "\033[0;34m[System] Requesting sudo privileges...\033[0m"
        sudo "$0" "$@"
        exit $?
    fi
}

confirm_reboot() {
    local WARNING_MESSAGE="WARNING: this will REBOOT !!!!. Do you wish to continue? (y/N): "
    echo -n "${WARNING_MESSAGE}"
    read -r USER_INPUT

    if ! [[ "$USER_INPUT" =~ ^[yY]$ ]]; then
        echo "Operation cancelled by the user. Stopping script."
        exit 0
    fi
}

# Usage: apply_grub_and_reboot <template_file> <output_file> <menu_entry> <backup_filename>
apply_grub_and_reboot() {
    local src="$1"
    local dst="$2"
    local menu_entry="$3"
    local backup_filename="$4"

    if [ ! -f "$src" ]; then
        error_exit "Source file '${src}' not found."
    fi

    # Escape filename for sed
    local escaped_filename=$(printf '%s\n' "$backup_filename" | sed 's/[\/&]/\\&/g')

    sed -e "s|@@MENU_ENTRY@@|${menu_entry}|g" \
        -e "s|@@ISO_FILE@@|${ISO_FILE}|g" \
        -e "s|@@REPOSITORY@@|${REPOSITORY}|g" \
        -e "s|@@BACKUP_DIR@@|${BACKUP_DIR}|g" \
        -e "s|@@BACKUP_FILENAME@@|${escaped_filename}|g" \
        -e "s|@@TARGET_DISK@@|${TARGET_DISK}|g" \
        "$src" > "$dst"

    if [ $? -ne 0 ]; then
        error_exit "SED operation failed."
    fi
    echo "Success: Content saved to '${dst}' with substitution '${backup_filename}'."

    if ! mv -f "$dst" /etc/grub.d/40_custom; then
        error_exit "Failed to move '${dst}' to /etc/grub.d/40_custom."
    fi
    
    # CRITICAL: update-grub ignores files in /etc/grub.d that aren't executable
    chmod +x /etc/grub.d/40_custom

    echo "## Installing cleanup service..."
    local SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
    cp -f "$SCRIPT_DIR/grub-cleanup.sh" /usr/local/sbin/grub-cleanup.sh || error_exit "Failed to copy grub-cleanup.sh"
    chmod +x /usr/local/sbin/grub-cleanup.sh
    cp -f "$SCRIPT_DIR/grub-cleanup.service" /etc/systemd/system/grub-cleanup.service || error_exit "Failed to copy grub-cleanup.service"
    chmod 644 /etc/systemd/system/grub-cleanup.service
    systemctl daemon-reload

    echo "## Enabling one-time cleanup service for next boot..."
    systemctl enable grub-cleanup.service || error_exit "Failed to enable grub-cleanup.service."
    
    echo "## Running update-grub..."
    update-grub || error_exit "Failed to update grub configuration."
    
    echo "## Setting next boot entry to '$menu_entry'..."
    grub-reboot "$menu_entry" || error_exit "Failed to set grub-reboot for '$menu_entry'."

    echo ""
    for i in $(seq 5 -1 1); do
        printf "\rSystem will reboot in %d seconds... (Press Ctrl+C to cancel)" "$i"
        sleep 1
    done
    echo -e "\nRebooting now..."
    reboot now
}