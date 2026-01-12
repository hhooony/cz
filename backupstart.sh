#!/bin/bash

SRC="template.40_custom"
DST="output.40_custom"
STRING_TO_REPLACE="filename_backup"
WARNING_MESSAGE="WARNING: this will REBOOT !!!!. Do you wish to continue? (y/N): "

echo -n "${WARNING_MESSAGE}"
read USER_INPUT

if ! [[ "$USER_INPUT" =~ ^[yY]$ ]]; then
    echo "Operation cancelled by the user. Stopping script."
    exit 1
fi

if [ ! -f "$SRC" ]; then
    echo "Error: Source file '${SRC}' not found. Stopping script."
    exit 1
fi


FILENAME_PREF=""

while true; do
    echo -n "Please enter the desired filename prefix (e.g. Backup_before_modification) : "
    read FILENAME_PREF

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

#echo "---"
#echo "Generating new Custom GRUB enrty with backup filename '${NEW_SUBSTITUTION}'."
sed "s/${STRING_TO_REPLACE}/${NEW_SUBSTITUTION}/g" "$SRC" > "$DST"

# Check if the sed operation was successful
if [ $? -eq 0 ]; then
    echo "Success: Content saved to '${DST}'. (New substitution: ${NEW_SUBSTITUTION})"
else
    echo "Error: SED operation failed."
    exit 1
fi

# Overwrite grub custom script
if ! cp -f "$DST" /etc/grub.d/40_custom; then
    error_exit "Failed to copy '$DST' to /etc/grub.d/40_custom."
fi

if ! update-grub; then
    error_exit "Failed to update grub configuration."
fi

if ! grub-reboot "Clonezilla_Backup"; then
    error_exit "Failed to set grub-reboot for 'Clonezilla'."
fi

echo "reboot in 5 sec"
sleep 5

reboot now


