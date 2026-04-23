#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
source "$SCRIPT_DIR/clonezilla.conf"
source "$SCRIPT_DIR/common.sh"

require_root
confirm_reboot

FOLDER_PREF=""                  # optional prefix filter
SRC="template.40_custom_restore"
DST="output.40_custom"
MENU_ENTRY="Clonezilla_Restore"

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

# Execute grub update and reboot process from common logic
apply_grub_and_reboot "$SRC" "$DST" "$MENU_ENTRY" "$FOLDER_SELECT"
