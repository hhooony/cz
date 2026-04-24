#!/bin/bash

GRUB_CUSTOM_FILE="/etc/grub.d/40_custom"
SYSTEMD_SERVICE_NAME="grub-cleanup.service"

echo "## Starting GRUB cleanup process..."

# signal file (/etc/grub.d/40_custom)
if [ -f "$GRUB_CUSTOM_FILE" ]; then
    echo "## Found signal file: $GRUB_CUSTOM_FILE. Removing it."
    if ! rm -f "$GRUB_CUSTOM_FILE"; then
        echo "## Error: Failed to remove $GRUB_CUSTOM_FILE. Exiting." >&2
        exit 1
    fi

    echo "## Running update-grub to remove Clonezilla entries..."
    if ! update-grub; then
        echo "## Error: update-grub failed. Manual intervention may be required." >&2
    else
        echo "## update-grub completed successfully."
    fi
else
    echo "## Signal file $GRUB_CUSTOM_FILE not found. Nothing to do for GRUB."
fi

echo "## Disabling and removing the systemd service ($SYSTEMD_SERVICE_NAME)..."
systemctl disable "$SYSTEMD_SERVICE_NAME"
rm -f "/etc/systemd/system/$SYSTEMD_SERVICE_NAME"
systemctl daemon-reload

echo "## GRUB cleanup process finished."
exit 0