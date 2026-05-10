#!/usr/bin/env bash

etxe_configure_display_manager() {
  etxe_log "Enabling SDDM"
  arch-chroot "$ETXE_MOUNT" systemctl enable sddm.service
}

etxe_configure_display_manager
