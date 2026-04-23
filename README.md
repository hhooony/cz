# Backup and Restore Functionality

## Overview

This README provides an understanding of the backup and restore functionality implemented in this project. The purpose of this feature is to ensure that users can easily backup their data and restore it whenever necessary.

## Backup Functionality

### Description

The backup functionality allows users to create a snapshot of their current data. It helps in preserving the state of the application at a specific moment in time, which can be crucial for data recovery in case of corruption or loss.

### How to Use

1. Navigate to the Backup section in the application.
2. Select the data you wish to backup (e.g., databases, files).
3. Click on the "Create Backup" button.
4. A confirmation message will appear indicating the backup was successful, along with the backup timestamp.

### Features
- Schedule backups at regular intervals.
- Options to backup specific folders or entire directories.

## Restore Functionality

### Description

The restore functionality enables users to revert their application state to a previously saved backup. This is vital in scenarios where data has been lost or corrupted, and recovery is necessary.

### How to Use

1. Navigate to the Restore section in the application.
2. Choose the backup file you wish to restore from the list.
3. Click on the "Restore" button.
4. Confirm that you wish to proceed with the restoration process; once confirmed, the application will revert to the state at the time the backup was created.

### Considerations
- Restoring a backup will overwrite current data; please ensure that this is done cautiously.
- It is recommended to take a new backup before restoring, in case you need to revert back to the current state.

## Conclusion

The backup and restore functionality provides a safety net for users, ensuring that valuable data can be easily recovered during unexpected issues. Following the steps outlined above will help users effectively manage their data backups and restorations.
=======
# Clonezilla Automation Scripts

Clonezilla를 활용한 시스템 백업 및 복구 자동화 스크립트입니다. 일회성 GRUB 부팅 항목을 생성하고, 작업 완료 후 자동으로 시스템 상태를 원상 복구합니다.

## Features
- **간편한 백업 & 복구**: 타임스탬프가 포함된 자동 백업 기능 및 선택형 복구 기능 제공.
- **자동 정리(Self-Cleaning)**: 작업 완료 후 `systemd` 서비스를 통해 임시 GRUB 설정을 자동으로 정리.
- **중앙화된 설정**: `clonezilla.conf` 파일 하나로 모든 시스템 변수 제어.

## Setup
1. 모든 스크립트 파일을 동일한 디렉토리에 위치시킵니다.
2. `clonezilla.conf` 파일을 열어 시스템 환경에 맞게 변수를 수정합니다. (디스크 UUID, 타겟 디스크 등)

## Usage
**주의**: 아래 명령어를 실행하면 시스템이 재부팅됩니다. 실행 전 모든 작업을 저장하세요.

### 시스템 백업
```bash
sudo ./backupstart.sh
```

### To Restore a Backup

Navigate to the script directory and run:
```bash
sudo ./restore_backup.sh
```

