# Clonezilla Automation Scripts

This project provides a set of shell scripts to automate system backup and restore operations using Clonezilla. It dynamically creates a one-time GRUB boot entry to run Clonezilla and then automatically cleans up the entry on the next successful boot, ensuring the system remains in a clean state.

## Features

- **Automated Backup**: Run a single script to create a full system backup with a timestamped filename.
- **Interactive Restore**: Lists available backups from a repository and allows the user to select which one to restore.
- **One-Time Boot**: Uses `grub-reboot` to automatically select the Clonezilla entry for the next boot only.
- **Self-Cleaning**: A `systemd` service automatically removes the temporary GRUB entry and disables itself after the Clonezilla operation is complete.
- **Safe**: Requires root privileges and user confirmation before proceeding with a reboot.

## How It Works

1.  **Initiation**: The user runs `backupstart.sh` or `restore_backup.sh` with `sudo`.
2.  **GRUB Configuration**: The script generates a temporary `/etc/grub.d/40_custom` file with the appropriate Clonezilla menu entry.
3.  **Cleanup Service**: It enables a one-time `systemd` service (`grub-cleanup.service`) which is configured to run on the next boot.
4.  **Reboot into Clonezilla**: The script runs `update-grub`, sets the one-time boot entry with `grub-reboot`, and reboots the machine.
5.  **Clonezilla Operation**: The system boots directly into Clonezilla, which automatically performs the backup or restore operation and then reboots again.
6.  **Automatic Cleanup**: On the next normal boot, `systemd` detects the presence of `/etc/grub.d/40_custom` and triggers `grub-cleanup.service`.
7.  **Finalization**: The `grub-cleanup.sh` script removes the temporary GRUB file, runs `update-grub` to clean the menu, and finally disables and deletes its own `systemd` service file. The system is now back to its original state.

## Components

- `backupstart.sh`: Script to initiate a system backup.
- `restore_backup.sh`: Script to initiate a system restore from a list of available backups.
- `grub-cleanup.sh`: The cleanup script that is executed by `systemd`. It removes the temporary GRUB entry and the service itself.
- `grub-cleanup.service`: The `systemd` unit file that defines the one-time cleanup service.
- `template.40_custom_backup`: The GRUB menu entry template for the backup operation.
- `template.40_custom_restore`: The GRUB menu entry template for the restore operation.

## Prerequisites

- A Debian-based system (e.g., Debian, Ubuntu, OpenMediaVault) with `systemd` and GRUB.
- `clonezilla.iso` file must be placed in the root directory (`/`).
- A dedicated partition for storing backups. The UUID of this partition must be configured in the template files.
- The target disk for backup/restore is hardcoded as `nvme0n1` in the templates. Adjust if necessary.

## Setup

1.  **Place Scripts**: Place `backupstart.sh` and `restore_backup.sh` in a convenient location (e.g., `/home/user/scripts`).

2.  **Configure Templates**:
    - Edit `template.40_custom_backup` and `template.40_custom_restore`.
    - Replace the `ocs_repository` UUID (`dda24e6b-a4e0-4b79-90b9-82a1a2bb906d`) with the UUID of your backup partition.
    - Ensure the `ocs_live_run` parameter correctly targets your system disk (e.g., `nvme0n1`).

3.  **Configure Restore Script**:
    - Edit `restore_backup.sh`.
    - Update the `FOLDER_REPOS` variable to match the mount point of your backup partition.

## Usage

**Important**: These scripts will reboot the machine. Ensure all work is saved before running.

### To Create a Backup

Navigate to the script directory and run:
```bash
sudo ./backupstart.sh
```

### To Restore a Backup

Navigate to the script directory and run:
```bash
sudo ./restore_backup.sh
```