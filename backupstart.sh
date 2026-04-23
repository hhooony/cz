#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
source "$SCRIPT_DIR/clonezilla.conf"
source "$SCRIPT_DIR/common.sh"

require_root
confirm_reboot

SRC="template.40_custom_backup"
DST="output.40_custom"
MENU_ENTRY="Clonezilla_Backup"

FILENAME_PREF=""

while true; do
    echo -n "Please enter the desired filename prefix (e.g. Backup_before_modification) : "
    read -r FILENAME_PREF

    # Check if the input is empty
    if [ -z "$FILENAME_PREF" ]; then
        echo "Validation Failed: Prefix cannot be empty. Please try again."
        continue
    fi
	# Allow letters, numbers, underscore, dash, dot
    if [[ "$FILENAME_PREF" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        echo "Prefix '$FILENAME_PREF' accepted."
        break
    else
        echo "Validation Failed: Prefix contains invalid characters or spaces. Use letters, numbers, '.', '-', '_' only."
    fi
done

DATETIME_STAMP=$(date +%Y%m%d-%H%M%S)
NEW_SUBSTITUTION="${FILENAME_PREF}-${DATETIME_STAMP}"

# Execute grub update and reboot process from common logic
apply_grub_and_reboot "$SRC" "$DST" "$MENU_ENTRY" "$NEW_SUBSTITUTION"
