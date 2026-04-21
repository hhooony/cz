#!/usr/bin/env bash

SRC="template.40_custom_backup"
DST="output.40_custom"
STRING_TO_REPLACE="filename_backup"
WARNING_MESSAGE="WARNING: this will REBOOT !!!!. Do you wish to continue? (y/N): "

if [ "$EUID" -ne 0 ]; then
    echo -e "\033[0;34m[System] Requesting sudo privileges...\033[0m"
    sudo "$0" "$@"
    exit $?
fi

error_exit() {
    echo "Error: $1" >&2
    exit 1
}

echo -n "${WARNING_MESSAGE}"
read -r USER_INPUT

if ! [[ "$USER_INPUT" =~ ^[yY]$ ]]; then
    echo "Operation cancelled by the user. Stopping script."
    exit 0
fi

if [ ! -f "$SRC" ]; then
    error_exit "Source file '${SRC}' not found."
fi


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

#echo "---"
#echo "Generating new Custom GRUB enrty with backup filename '${NEW_SUBSTITUTION}'."
## sed 명령어 안정성 향상: 구분자를 '|'로 변경하여 파일 이름에 '/'가 포함되어도 안전하게 처리합니다.
sed "s|${STRING_TO_REPLACE}|${NEW_SUBSTITUTION}|g" "$SRC" > "$DST"

# Check if the sed operation was successful
if [ $? -eq 0 ]; then
    echo "Success: Content saved to '${DST}'. (New substitution: ${NEW_SUBSTITUTION})"
else
    error_exit "SED operation failed."
fi

# Overwrite grub custom script
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

if ! grub-reboot "Clonezilla_Backup"; then
    error_exit "Failed to set grub-reboot for 'Clonezilla_Backup'."
fi


echo ""
for i in $(seq 5 -1 1); do
    printf "\rSystem will reboot in %d seconds... (Press Ctrl+C to cancel)" "$i"
    sleep 1
done
echo -e "\nRebooting now..."
reboot now
