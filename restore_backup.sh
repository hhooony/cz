#!/usr/bin/env bash

# mount --mkdir /dev/sdb2 /mnt/sdb2
FOLDER_REPOS="/srv/dev-disk-by-uuid-dda24e6b-a4e0-4b79-90b9-82a1a2bb906d/backup_sys"
FOLDER_PREF=""                  # optional prefix filter
SRC="template.40_custom"
DST="output.40_custom"
STRING_TO_REPLACE="filename_restore"
WARNING_MESSAGE="WARNING: this will REBOOT !!!!. Do you wish to continue? (y/N): "

# -------------------------------
# Functions
# -------------------------------
error_exit() {
    echo "Error: $1"
    exit 1
}

# -------------------------------
# User confirmation
# -------------------------------
echo -n "${WARNING_MESSAGE}"
read USER_INPUT

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
    read -rp "Select the buckup-number to restore : " user_input

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
echo "press any key to continie..."
read

# -------------------------------
# Generate new GRUB entry
# -------------------------------
escaped_folder=$(printf '%s\n' "$FOLDER_SELECT" | sed 's/[\/&]/\\&/g')
if ! sed "s|${STRING_TO_REPLACE}|${escaped_folder}|g" "$SRC" > "$DST"; then
    error_exit "SED operation failed."
fi
echo "Success: Content saved to '${DST}' with substitution '${FOLDER_SELECT}'."

# -------------------------------
# Overwrite grub custom script
# -------------------------------
if ! cp -f "$DST" /etc/grub.d/40_custom; then
    error_exit "Failed to copy '$DST' to /etc/grub.d/40_custom."
fi

if ! update-grub; then
    error_exit "Failed to update grub configuration."
fi

if ! grub-reboot "Clonezilla_Restore"; then
    error_exit "Failed to set grub-reboot for 'Clonezilla_Restore'."
fi

# -------------------------------
# Reboot
# -------------------------------
echo "System will reboot in 5 seconds..."
sleep 5
echo "reboot now"
reboot now
