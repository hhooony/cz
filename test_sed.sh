#!/usr/bin/env bash

# 1. Define the variables
STRING_TO_REPLACE="filename_backup" #filename_backup
NEW_SUBSTITUTION="test_backup_name_here"
SRC="template.40_custom_backup"
DST="test_output.40_custom"


# 3. Run the sed command you want to test
echo "Running sed substitution..."
sed "s|${STRING_TO_REPLACE}|${NEW_SUBSTITUTION}|g" "$SRC" > "$DST"

echo -e "\n=== Modified File ($DST) ==="
cat "$DST"