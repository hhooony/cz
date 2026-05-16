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
# Print folder list
# -------------------------------
print_backup_list || error_exit "Cannot proceed without backups."

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
