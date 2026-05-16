#!/usr/bin/env bash

# usb-mount.sh
# A utility script to safely list, mount, unmount, and check the status of USB block devices.
# It strictly handles allowed filesystems and prevents modifications to protected system mount points.
# The script incorporates dynamic styling using 'ui2.sh' for consistent visual feedback.
# Usage: sudo ./usb-mount.sh {list|mount|umount|status} [DEVICE]

# Load ui2.sh
UI2_LIB="/datadisk/home/yh/lib/ui2.sh"
if [[ -f "$UI2_LIB" ]]; then
    source "$UI2_LIB"
else
    echo -e "\033[1;33m[WARN] $UI2_LIB not found. You can clone it from https://github.com/hhooony/ui2.git\033[0m" >&2
fi

# Fallbacks in case ui2.sh functions aren't loaded or use slightly different names
type info &>/dev/null || info() { echo -e "\033[1;34m[INFO]\033[0m $*"; }
type success &>/dev/null || success() { echo -e "\033[1;32m[SUCCESS]\033[0m $*"; }
type warn &>/dev/null || warn() { echo -e "\033[1;33m[WARN]\033[0m $*" >&2; }
type error &>/dev/null || error() { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; }

set -Eeuo pipefail

BASE_DIR="/srv"

log() {
    info "$*"
}

die() {
    error "$*"
    exit 1
}

require_root() {
    if [ "$EUID" -ne 0 ]; then
        info "Requesting sudo privileges..."
        sudo "$(realpath "$0")" "$@"
        exit $?
    fi
}

require_cmds() {
    local missing=()
    for cmd in blkid lsblk mount umount findmnt mkdir realpath readlink awk grep sed find; do
        command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
    done
    [[ ${#missing[@]} -eq 0 ]] || die "Missing commands: ${missing[*]}"
}

is_usb_block_device() {
    local devname="$1"
    [[ -e "/sys/block/$devname" ]] || return 1

    local link
    link="$(readlink -f "/sys/block/$devname")" || return 1
    [[ "$link" == *"/usb"* ]]
}

is_allowed_fstype() {
    local fstype="$1"
    case "$fstype" in
        ext2|ext3|ext4|xfs|btrfs|ntfs|ntfs3|exfat|vfat|fat|msdos)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

is_forbidden_fstype() {
    local fstype="$1"
    case "$fstype" in
        zfs_member|swap|crypto_LUKS|LVM2_member|linux_raid_member)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

is_protected_mountpoint() {
    local mp="$1"
    case "$mp" in
        /|/boot|/boot/efi)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

resolve_input_device() {
    local input="$1"

    [[ -n "$input" ]] || die "Device path is required."
    [[ -e "$input" ]] || die "Path not found: $input"

    case "$input" in
        /dev/disk/by-id/*|/dev/*)
            realpath "$input"
            ;;
        *)
            die "Unsupported path: $input"
            ;;
    esac
}

resolve_fs_device() {
    local dev="$1"

    [[ -b "$dev" ]] || die "Block device not found: $dev"

    if blkid -o value -s UUID "$dev" >/dev/null 2>&1; then
        echo "$dev"
        return 0
    fi

    local child
    while IFS= read -r child; do
        [[ -n "$child" ]] || continue
        if blkid -o value -s UUID "$child" >/dev/null 2>&1; then
            echo "$child"
            return 0
        fi
    done < <(lsblk -lnpo NAME "$dev" | tail -n +2)

    die "No filesystem with UUID found on $dev or its child partitions."
}

get_uuid() {
    local dev="$1"
    blkid -o value -s UUID "$dev" 2>/dev/null || die "Cannot read UUID from $dev"
}

get_fstype() {
    local dev="$1"
    blkid -o value -s TYPE "$dev" 2>/dev/null || die "Cannot read filesystem type from $dev"
}

get_mountpoint() {
    local uuid="$1"
    echo "${BASE_DIR}/dev-disk-by-uuid-${uuid}"
}

get_mount_opts() {
    local fstype="$1"
    case "$fstype" in
        ext2|ext3|ext4|xfs|btrfs)
            echo "rw,noatime"
            ;;
        ntfs|ntfs3)
            echo "rw,noatime,uid=0,gid=100,umask=0022"
            ;;
        exfat|vfat|fat|msdos)
            echo "rw,noatime,uid=0,gid=100,umask=0022"
            ;;
        *)
            echo "rw,noatime"
            ;;
    esac
}

get_parent_block_device() {
    local fsdev="$1"
    local pkname
    pkname="$(lsblk -no PKNAME "$fsdev" 2>/dev/null || true)"
    if [[ -n "$pkname" ]]; then
        echo "$pkname"
    else
        basename "$fsdev"
    fi
}

assert_safe_fsdev() {
    local fsdev="$1"
    local pkname fstype mp

    [[ -b "$fsdev" ]] || die "Not a block device: $fsdev"

    pkname="$(get_parent_block_device "$fsdev")"
    is_usb_block_device "$pkname" || die "Refusing non-USB device: $fsdev"

    fstype="$(get_fstype "$fsdev")"

    is_forbidden_fstype "$fstype" && die "Refusing dangerous filesystem type: $fstype"
    is_allowed_fstype "$fstype" || die "Refusing unsupported filesystem type: $fstype"

    mp="$(findmnt -rn -S "$fsdev" -o TARGET || true)"
    if [[ -n "$mp" ]] && is_protected_mountpoint "$mp"; then
        die "Refusing protected mountpoint: $mp"
    fi
}

get_usb_byid_for_device() {
    local devbase="$1"
    find /dev/disk/by-id -maxdepth 1 -type l -lname "../../${devbase}" 2>/dev/null | grep '/usb-' | head -n1 || true
}

list_usb_fs_devices() {
    local dev pkname fstype
    while IFS= read -r dev; do
        [[ -n "$dev" ]] || continue

        pkname="$(get_parent_block_device "$dev")"
        is_usb_block_device "$pkname" || continue

        fstype="$(get_fstype "$dev" 2>/dev/null || true)"
        [[ -n "$fstype" ]] || continue
        is_forbidden_fstype "$fstype" && continue
        is_allowed_fstype "$fstype" || continue

        echo "$dev"
    done < <(blkid -o device | sort -u)
}

list_usb_unmounted_fs_devices() {
    local dev mp
    while IFS= read -r dev; do
        [[ -n "$dev" ]] || continue
        mp="$(findmnt -rn -S "$dev" -o TARGET || true)"
        if [[ -z "$mp" ]]; then
            echo "$dev"
        fi
    done < <(list_usb_fs_devices)
}

list_usb_mounted_fs_devices() {
    local dev mp
    while IFS= read -r dev; do
        [[ -n "$dev" ]] || continue
        mp="$(findmnt -rn -S "$dev" -o TARGET || true)"
        if [[ -n "$mp" ]]; then
            echo "$dev"
        fi
    done < <(list_usb_fs_devices)
}

print_usb_list() {
    local dev uuid fstype mp byid size model found=0

    info "USB filesystem devices:"
    while IFS= read -r dev; do
        [[ -n "$dev" ]] || continue
        found=1

        uuid="$(get_uuid "$dev" 2>/dev/null || echo "-")"
        fstype="$(get_fstype "$dev" 2>/dev/null || echo "-")"
        mp="$(findmnt -rn -S "$dev" -o TARGET || true)"
        byid="$(get_usb_byid_for_device "$(basename "$dev")")"
        size="$(lsblk -dnro SIZE "$dev" 2>/dev/null || echo "-")"
        model="$(lsblk -dnro MODEL "/dev/$(get_parent_block_device "$dev")" 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' || echo "-")"

        echo -e "  \033[1;36mdevice\033[0m     : $dev"
        echo -e "  \033[1;36mby-id\033[0m      : ${byid:-"-"}"
        echo -e "  \033[1;36mmodel\033[0m      : ${model:-"-"}"
        echo -e "  \033[1;36msize\033[0m       : ${size:-"-"}"
        echo -e "  \033[1;36mfstype\033[0m     : $fstype"
        echo -e "  \033[1;36muuid\033[0m       : $uuid"
        echo -e "  \033[1;36mmounted\033[0m    : ${mp:-no}"
        echo
    done < <(list_usb_fs_devices)

    [[ $found -eq 1 ]] || warn "  (none)"
}

pick_single_unmounted_usb_fs() {
    mapfile -t candidates < <(list_usb_unmounted_fs_devices)
    case "${#candidates[@]}" in
        0)
            die "No unmounted USB filesystem found."
            ;;
        1)
            echo "${candidates[0]}"
            ;;
        *)
            warn "Multiple unmounted USB filesystems found:"
            printf '  \033[1;33m%s\033[0m\n' "${candidates[@]}" >&2
            info "Please specify one explicitly." >&2
            exit 2
            ;;
    esac
}

pick_single_mounted_usb_fs() {
    mapfile -t candidates < <(list_usb_mounted_fs_devices)
    case "${#candidates[@]}" in
        0)
            die "No mounted USB filesystem found."
            ;;
        1)
            echo "${candidates[0]}"
            ;;
        *)
            warn "Multiple mounted USB filesystems found:"
            printf '  \033[1;33m%s\033[0m\n' "${candidates[@]}" >&2
            info "Please specify one explicitly." >&2
            exit 2
            ;;
    esac
}

do_mount_device() {
    local fsdev="$1"
    local uuid fstype mp opts

    assert_safe_fsdev "$fsdev"

    uuid="$(get_uuid "$fsdev")"
    fstype="$(get_fstype "$fsdev")"
    mp="$(get_mountpoint "$uuid")"
    opts="$(get_mount_opts "$fstype")"

    mkdir -p "$mp"

    if findmnt -rn -S "$fsdev" >/dev/null 2>&1 || findmnt -rn "$mp" >/dev/null 2>&1; then
        warn "Already mounted: $fsdev -> $mp"
        return 0
    fi

    mount -o "$opts" "$fsdev" "$mp"
    success "Mounted: $fsdev ($fstype, UUID=$uuid) -> $mp"
}

do_umount_device() {
    local fsdev="$1"
    local uuid mp

    assert_safe_fsdev "$fsdev"

    uuid="$(get_uuid "$fsdev")"
    mp="$(get_mountpoint "$uuid")"

    if findmnt -rn "$mp" >/dev/null 2>&1; then
        sync
        umount "$mp"
        success "Unmounted: $mp"
    else
        warn "Not mounted: $mp"
    fi
}

do_mount() {
    local input="${1:-}"
    local dev fsdev

    if [[ -n "$input" ]]; then
        dev="$(resolve_input_device "$input")"
        fsdev="$(resolve_fs_device "$dev")"
    else
        fsdev="$(pick_single_unmounted_usb_fs)"
    fi

    do_mount_device "$fsdev"
}

do_umount() {
    local input="${1:-}"
    local dev fsdev

    if [[ -n "$input" ]]; then
        dev="$(resolve_input_device "$input")"
        fsdev="$(resolve_fs_device "$dev")"
    else
        fsdev="$(pick_single_mounted_usb_fs)"
    fi

    do_umount_device "$fsdev"
}

do_status() {
    local input="${1:-}"
    local dev fsdev uuid fstype mp byid parent

    if [[ -n "$input" ]]; then
        dev="$(resolve_input_device "$input")"
        fsdev="$(resolve_fs_device "$dev")"
    else
        fsdev="$(pick_single_unmounted_usb_fs 2>/dev/null || true)"
        [[ -n "${fsdev:-}" ]] || fsdev="$(pick_single_mounted_usb_fs)"
    fi

    assert_safe_fsdev "$fsdev"

    uuid="$(get_uuid "$fsdev")"
    fstype="$(get_fstype "$fsdev")"
    mp="$(get_mountpoint "$uuid")"
    parent="$(get_parent_block_device "$fsdev")"
    byid="$(get_usb_byid_for_device "$(basename "$fsdev")")"

    info "Device Status:"
    local mounted
    findmnt -rn "$mp" >/dev/null 2>&1 && mounted="\033[1;32myes\033[0m" || mounted="\033[1;31mno\033[0m"
    echo -e "  \033[1;36mFS device\033[0m   : $fsdev"
    echo -e "  \033[1;36mParent disk\033[0m : /dev/$parent"
    echo -e "  \033[1;36mUSB by-id\033[0m   : ${byid:-"-"}"
    echo -e "  \033[1;36mUUID\033[0m        : $uuid"
    echo -e "  \033[1;36mFSType\033[0m      : $fstype"
    echo -e "  \033[1;36mMount point\033[0m : $mp"
    echo -e "  \033[1;36mMounted\033[0m     : $mounted"
}

usage() {
    cat <<EOF
Usage:
  $(basename "$0") list
  $(basename "$0") mount [DEVICE]
  $(basename "$0") umount [DEVICE]
  $(basename "$0") status [DEVICE]

Examples:
  $(basename "$0") list
  $(basename "$0") mount
  $(basename "$0") umount
  $(basename "$0") status
  $(basename "$0") mount /dev/disk/by-id/usb-WD_Elements_10A8_575846314138333530333730-0:0-part1
  $(basename "$0") umount /dev/disk/by-id/usb-WD_Elements_10A8_575846314138333530333730-0:0-part1
EOF
}

main() {
    require_cmds
    require_root "$@"

    local action="${1:-}"
    local input="${2:-}"

    case "$action" in
        list)
            print_usb_list
            ;;
        mount)
            do_mount "$input"
            ;;
        umount)
            do_umount "$input"
            ;;
        status)
            do_status "$input"
            ;;
        *)
            usage
            exit 1
            ;;
    esac
}

main "$@"
