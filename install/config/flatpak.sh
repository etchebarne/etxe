#!/usr/bin/env bash

etxe_configure_flatpak() {
  etxe_log "Adding Flathub"
  arch-chroot "$ETXE_MOUNT" flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || true
}

etxe_configure_flatpak
