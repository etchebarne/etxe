#!/usr/bin/env bash

etxe_configure_networking() {
  etxe_log "Configuring NetworkManager and systemd-resolved"

  arch-chroot "$ETXE_MOUNT" systemctl enable NetworkManager.service
  arch-chroot "$ETXE_MOUNT" systemctl enable systemd-resolved.service
  ln -sf /run/systemd/resolve/stub-resolv.conf "$ETXE_MOUNT/etc/resolv.conf"
}

etxe_configure_networking
