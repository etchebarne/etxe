#!/usr/bin/env bash

etxe_preflight_commands() {
  local command
  for command in arch-chroot blkid btrfs genfstab mkfs.btrfs mkfs.fat msgfmt pacstrap partprobe sed sgdisk tar udevadm; do
    command -v "$command" >/dev/null || etxe_die "$command is required; run from the Arch ISO"
  done
}

etxe_preflight_commands
