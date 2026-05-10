#!/usr/bin/env bash

etxe_install_flatpaks() {
  local -a flatpaks
  mapfile -t flatpaks < <(etxe_package_list "$ETXE_FLATPAK_PACKAGES_FILE")
  [[ "${#flatpaks[@]}" -gt 0 ]] || return 0

  etxe_log "Installing Flatpak apps from Flathub"
  if ! arch-chroot "$ETXE_MOUNT" flatpak install --system --noninteractive flathub "${flatpaks[@]}"; then
    etxe_log "Flatpak app installation failed; continuing without optional Flatpak apps"
  fi
}

etxe_install_flatpaks
