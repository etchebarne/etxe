#!/usr/bin/env bash

etxe_configure_flatpak() {
  if etxe_has_flatpak_system_bundle; then
    etxe_log "Using bundled Flatpak system"
    return 0
  fi

  etxe_log "Adding Flathub"
  arch-chroot "$ETXE_MOUNT" flatpak remote-add --system --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo \
    || etxe_die "failed to add Flathub remote"
}

etxe_configure_flatpak
