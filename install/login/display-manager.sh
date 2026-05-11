#!/usr/bin/env bash

etxe_configure_display_manager() {
  etxe_log "Enabling GDM"
  arch-chroot "$ETXE_MOUNT" systemctl enable gdm.service
}

etxe_configure_display_manager
