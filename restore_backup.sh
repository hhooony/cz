#!/usr/bin/env bash

# mount --mkdir /dev/sdb2 /mnt/sdb2
FOLDER_REPOS="/srv/dev-disk-by-uuid-dda24e6b-a4e0-4b79-90b9-82a1a2bb906d/backup_sys"
FOLDER_PREF=""                  # optional prefix filter
SRC="template.40_custom_restore"
DST="output.40_custom"
WARNING_MESSAGE="WARNING: this will REBOOT !!!!. Do you wish to continue? (y/N): "

# Clonezilla Configuration Variables
MENU_ENTRY="Clonezilla_Restore"
ISO_FILE="clonezilla.iso"
REPOSITORY="dev:///uuid=bbb79c06-4d29-4b73-b0ea-405a1c35de38"
BACKUP_DIR="backup_sys"
TARGET_DISK="nvme0n1"

error_exit() {
    echo "Error: $1"
    exit 1
}

if [ "$EUID" -ne 0 ]; then
    echo -e "\033[0;34m[System] Requesting sudo privileges...\033[0m"
    sudo "$0" "$@"
    exit $?
fi

# User confirmation
echo -n "${WARNING_MESSAGE}"
read -r USER_INPUT

if ! [[ "$USER_INPUT" =~ ^[yY]$ ]]; then
    echo "Operation cancelled by the user. Stopping script."
    exit 0
fi

# Check source file
if [ ! -f "$SRC" ]; then
    error_exit "Source file '${SRC}' not found."
fi

# -------------------------------
# Collect folder list sorted by mtime (newest first)
# -------------------------------
folders=()
folders_mtime=()
folders_size=()

if [[ -n "$FOLDER_PREF" ]]; then
    mapfile -t raw_list < <(
        find "$FOLDER_REPOS" -mindepth 1 -maxdepth 1 -type d -printf "%T@|%f\n" \
        | sort -nr \
        | grep "|${FOLDER_PREF}"
    )
else
    mapfile -t raw_list < <(
        find "$FOLDER_REPOS" -mindepth 1 -maxdepth 1 -type d -printf "%T@|%f\n" \
        | sort -nr
    )
fi

if [[ ${#raw_list[@]} -eq 0 ]]; then
    error_exit "No backups found in '$FOLDER_REPOS'."
fi

# Parse list and compute size + readable date
for entry in "${raw_list[@]}"; do
    timestamp="${entry%%|*}"
    folder_name="${entry##*|}"

    mtime_human=$(date -d "@$timestamp" "+%Y-%m-%d %H:%M:%S")
    folder_size=$(du -sh "$FOLDER_REPOS/$folder_name" 2>/dev/null | awk '{print $1}')

    folders+=("$folder_name")
    folders_mtime+=("$mtime_human")
    folders_size+=("$folder_size")
done

# -------------------------------
# Print folder list
# -------------------------------
echo "Available backups:"
for i in "${!folders[@]}"; do
    printf "%3d) %-40s | %s | %s\n" \
        "$((i+1))" \
        "${folders[$i]}" \
        "${folders_mtime[$i]}" \
        "${folders_size[$i]}"
done

# -------------------------------
# User folder selection
# -------------------------------
while true; do
    read -rp "Select the backup number to restore: " user_input

    if ! [[ "$user_input" =~ ^[0-9]+$ ]]; then
        echo "Numbers only."
        continue
    fi

    index=$((user_input - 1))

    if (( index < 0 || index >= ${#folders[@]} )); then
        echo "Invalid selection."
        continue
    fi

    break
done

FOLDER_SELECT="${folders[$index]}"
echo "Selected Backup to restore: $FOLDER_SELECT | ${folders_mtime[$index]} | ${folders_size[$index]}"
echo "Press Enter to continue..."
read -r

# -------------------------------
# Generate new GRUB entry
# -------------------------------
escaped_folder=$(printf '%s\n' "$FOLDER_SELECT" | sed 's/[\/&]/\\&/g')
if ! sed -e "s|@@MENU_ENTRY@@|${MENU_ENTRY}|g" \
         -e "s|@@ISO_FILE@@|${ISO_FILE}|g" \
         -e "s|@@REPOSITORY@@|${REPOSITORY}|g" \
         -e "s|@@BACKUP_DIR@@|${BACKUP_DIR}|g" \
         -e "s|@@BACKUP_FILENAME@@|${escaped_folder}|g" \
         -e "s|@@TARGET_DISK@@|${TARGET_DISK}|g" \
         "$SRC" > "$DST"; then
    error_exit "SED operation failed."
fi
echo "Success: Content saved to '${DST}' with substitution '${FOLDER_SELECT}'."

# -------------------------------
# Overwrite grub custom script
# -------------------------------
if ! cp -f "$DST" /etc/grub.d/40_custom; then
    error_exit "Failed to copy '$DST' to /etc/grub.d/40_custom."
fi

## 일회성 정리 서비스 설치 및 업데이트
echo "## Installing cleanup service..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
if ! cp -f "$SCRIPT_DIR/grub-cleanup.sh" /usr/local/sbin/grub-cleanup.sh; then
    error_exit "Failed to copy grub-cleanup.sh to /usr/local/sbin/"
fi
chmod +x /usr/local/sbin/grub-cleanup.sh

if ! cp -f "$SCRIPT_DIR/grub-cleanup.service" /etc/systemd/system/grub-cleanup.service; then
    error_exit "Failed to copy grub-cleanup.service to /etc/systemd/system/"
fi
systemctl daemon-reload

## 다음 부팅 시 일회성 정리 서비스를 활성화합니다.
echo "## Enabling one-time cleanup service for next boot..."
if ! systemctl enable grub-cleanup.service; then
    error_exit "Failed to enable grub-cleanup.service."
fi

if ! update-grub; then
    error_exit "Failed to update grub configuration."
fi

if ! grub-reboot "$MENU_ENTRY"; then
    error_exit "Failed to set grub-reboot for '$MENU_ENTRY'."
fi

echo ""
for i in $(seq 5 -1 1); do
    printf "\rSystem will reboot in %d seconds... (Press Ctrl+C to cancel)" "$i"
    sleep 1
done
echo -e "\nRebooting now..."
reboot now
