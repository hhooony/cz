#!/usr/bin/env bash


# 1. 교체할 대상 문자열 변수 정의 (Targets)
TARGET_MENU="@@MENU_ENTRY@@"
TARGET_ISO="@@ISO_FILE@@"
TARGET_REPO="@@REPOSITORY@@"
TARGET_DIR="@@BACKUP_DIR@@"
TARGET_FILE="@@BACKUP_FILENAME@@"
TARGET_DISK="@@TARGET_DISK@@"

# 2. 새롭게 치환할 값 정의 (New Values - 테스트용 예시)
NEW_MENU="Clonezilla_Backup_Custom"
NEW_ISO="clonezilla_custom.iso"
NEW_REPO="dev:///UUID=11112222-3333-4444-5555-666677778888"
NEW_DIR="my_backup_folder"
NEW_FILE="test_backup_name_here"
NEW_DISK="sda1"

SRC="template.40_custom_backup"
DST="test_output.40_custom"

# 3. 여러 개의 변수를 동시에 치환하는 sed 명령어 실행
echo "Running sed substitution..."
sed -e "s|${TARGET_MENU}|${NEW_MENU}|g" \
    -e "s|${TARGET_ISO}|${NEW_ISO}|g" \
    -e "s|${TARGET_REPO}|${NEW_REPO}|g" \
    -e "s|${TARGET_DIR}|${NEW_DIR}|g" \
    -e "s|${TARGET_FILE}|${NEW_FILE}|g" \
    -e "s|${TARGET_DISK}|${NEW_DISK}|g" \
    "$SRC" > "$DST"

echo -e "\n=== Modified File ($DST) ==="
cat "$DST"