#!/usr/bin/env bash

SRC="template.40_custom_backup"
DST="output.40_custom"
STRING_TO_REPLACE="filename_backup"
WARNING_MESSAGE="WARNING: this will REBOOT !!!!. Do you wish to continue? (y/N): "

## Q1. 루트 권한 확인: 이 스크립트는 시스템 파일을 수정하므로 루트 권한이 필요합니다.
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run as root. Please use 'sudo'." >&2
    exit 1
fi

error_exit() {
    echo "Error: $1" >&2
    exit 1
}

echo -n "${WARNING_MESSAGE}"
read USER_INPUT

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
## Q2. sed 명령어 안정성 향상: 구분자를 '|'로 변경하여 파일 이름에 '/'가 포함되어도 안전하게 처리합니다.
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

## show count down with additional message e.g 'ctrl-c to stop...' 
echo "reboot in 5 sec"
sleep 5

reboot now
