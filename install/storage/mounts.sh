#!/usr/bin/env bash

etxe_mount_filesystems() {
  local efi root
  efi="$(etxe_part_path "$DISK" 1)"
  root="$(etxe_part_path "$DISK" 2)"

  etxe_log "Mounting filesystems"
  mount -o "$ETXE_BTRFS_OPTS,subvol=@" "$root" "$ETXE_MOUNT"
  mkdir -p "$ETXE_MOUNT"/{boot,home,var/log,.snapshots}
  mount -o "$ETXE_BTRFS_OPTS,subvol=@home" "$root" "$ETXE_MOUNT/home"
  mount -o "$ETXE_BTRFS_OPTS,subvol=@var_log" "$root" "$ETXE_MOUNT/var/log"
  mount -o "$ETXE_BTRFS_OPTS,subvol=@snapshots" "$root" "$ETXE_MOUNT/.snapshots"
  mount "$efi" "$ETXE_MOUNT/boot"
}

etxe_mount_filesystems
