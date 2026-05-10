#!/usr/bin/env bash

etxe_create_subvolumes() {
  local root
  root="$(etxe_part_path "$DISK" 2)"

  etxe_log "Creating Btrfs subvolumes"
  mount "$root" "$ETXE_MOUNT"
  btrfs subvolume create "$ETXE_MOUNT/@"
  btrfs subvolume create "$ETXE_MOUNT/@home"
  btrfs subvolume create "$ETXE_MOUNT/@var_log"
  btrfs subvolume create "$ETXE_MOUNT/@snapshots"
  umount "$ETXE_MOUNT"
}

etxe_create_subvolumes
