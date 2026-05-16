#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

source "$SCRIPT_DIR/clonezilla.conf"
source "$SCRIPT_DIR/common.sh"

# 권한 상승 일원화
require_root

# Verify the REPOSITORY disk is available and mount it if needed
REPO_UUID=""
if [[ "$REPOSITORY" =~ UUID=([a-zA-Z0-9-]+) ]]; then
    REPO_UUID="${BASH_REMATCH[1]}"
elif [[ "$FOLDER_REPOS" =~ dev-disk-by-uuid-([a-zA-Z0-9-]+) ]]; then
    REPO_UUID="${BASH_REMATCH[1]}"
fi

if [[ -n "$REPO_UUID" ]]; then
    REPO_DEV="/dev/disk/by-uuid/$REPO_UUID"
    echo "Verifying REPOSITORY disk ($REPO_DEV) is available..."
    #####
    if ! "$SCRIPT_DIR/usb-mount.sh" mount "$REPO_DEV"; then
        echo "Error: REPOSITORY disk is not available or failed to mount."
        exit 1
    fi
else
    echo "Warning: Could not extract UUID from clonezilla.conf. Skipping verification."
fi

echo ""
echo "=================================================="
echo "   Current Backup Repository Status"
echo "=================================================="
print_backup_list
echo "=================================================="
echo ""

while true; do
    echo "Please select an operation:"
    echo "  1) Backup (Sync media, stop containers, and backup OS)"
    echo "  2) Restore (Recover OS from an existing backup)"
    echo "  q) Quit"
    read -r -p "Select (1/2/q): " choice

    case "$choice" in
        1)
            echo ""
            read -r -p "container stop: press any to continue..." dummy
            #####
            # 일반 사용자 권한으로 돌아가 홈 디렉토리의 스크립트 실행
            sudo -u "${SUDO_USER:-$USER}" bash -c '~/container-stop-run.sh stop'

            read -r -p "start rsync video files: press any to continue..." dummy
            # In Bash, if a wildcard does not match any files, it resolves to the literal string with the asterisk.
            # We use 'shopt -s nullglob' so unmatched wildcards expand to nothing, then check the array count.
            # Safely check if files exist before syncing them:
            shopt -s nullglob
            media_files=(/dockerdisk/tv/*)
            if [ ${#media_files[@]} -gt 0 ]; then
                echo "rsync start"
                #####
                rsync -a --progress --remove-source-files "${media_files[@]}" /datadisk/media_video/plex/down/
            fi
            shopt -u nullglob

            #####
            "$SCRIPT_DIR/backupstart.sh"
            break
            ;;
        2)
            echo ""
            "$SCRIPT_DIR/restore_backup.sh"
            break
            ;;
        q|Q)
            echo "Operation cancelled. Exiting."
            exit 0
            ;;
        *)
            echo "Invalid selection. Please enter 1, 2, or q."
            ;;
    esac
done
