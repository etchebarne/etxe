#!/usr/bin/env bash

etxe_format_filesystems() {
  local efi root
  efi="$(etxe_part_path "$DISK" 1)"
  root="$(etxe_part_path "$DISK" 2)"

  etxe_log "Formatting filesystems"
  mkfs.fat -F32 -n EFI "$efi"
  mkfs.btrfs -f -L ROOT "$root"
}

etxe_format_filesystems
