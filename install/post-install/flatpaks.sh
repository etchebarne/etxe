#!/usr/bin/env bash

etxe_install_flatpaks() {
  local -a flatpaks
  mapfile -t flatpaks < <(etxe_package_list "$ETXE_FLATPAK_PACKAGES_FILE")
  [[ "${#flatpaks[@]}" -gt 0 ]] || return 0

  if etxe_has_flatpak_system_bundle; then
    etxe_log "Installing bundled Flatpak system"
    install -d -m 0755 "$ETXE_MOUNT/var/lib"
    rm -rf "$ETXE_MOUNT/var/lib/flatpak"
    install -d -m 0755 "$ETXE_MOUNT/var/lib/flatpak"
    tar --acls --xattrs -C "$ETXE_MOUNT/var/lib/flatpak" -xf "$ETXE_FLATPAK_SYSTEM_ARCHIVE"
    for flatpak in "${flatpaks[@]}"; do
      arch-chroot "$ETXE_MOUNT" flatpak info --system "$flatpak" >/dev/null \
        || etxe_die "bundled Flatpak app is missing after install: $flatpak"
    done
    return 0
  fi

  etxe_log "Installing Flatpak apps from Flathub"
  arch-chroot "$ETXE_MOUNT" flatpak install --system --noninteractive --assumeyes --or-update flathub "${flatpaks[@]}" \
    || etxe_die "failed to install Flatpak apps from Flathub"
}

etxe_install_flatpaks
