#!/usr/bin/env bash

etxe_partition_disk() {
  etxe_log "Partitioning $DISK"
  swapoff --all || true
  umount -R "$ETXE_MOUNT" 2>/dev/null || true

  sgdisk --zap-all "$DISK"
  sgdisk --new=1:0:+1G --typecode=1:ef00 --change-name=1:EFI "$DISK"
  sgdisk --new=2:0:0 --typecode=2:8300 --change-name=2:ROOT "$DISK"
  partprobe "$DISK"
  udevadm settle
}

etxe_partition_disk
