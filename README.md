# Clonezilla Automation Scripts

Automated system backup and recovery scripts using Clonezilla. Creates one-time GRUB boot entries and self-cleans after completion.

## Setup
1. Place all scripts in the same directory.
2. Configure variables in `clonezilla.conf` (e.g., disk UUIDs, target disks).

## Usage
**Warning**: These commands will reboot your system immediately. Save all work before running.

### Backup
```bash
sudo ./backupstart.sh
```

### To Restore a Backup

Navigate to the script directory and run:
```bash
sudo ./restore_backup.sh
```
