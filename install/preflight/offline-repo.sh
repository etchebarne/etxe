#!/usr/bin/env bash

etxe_preflight_offline_repo() {
  local -a flatpaks

  if [[ "${ETXE_REQUIRE_OFFLINE_REPO:-}" == "YES" ]]; then
    etxe_has_offline_repo || etxe_die "missing offline repository at $ETXE_OFFLINE_REPO"
  fi

  if etxe_has_offline_repo; then
    etxe_log "Offline repository found at $ETXE_OFFLINE_REPO"
  else
    etxe_log "No offline repository found; package installation requires internet"
  fi

  mapfile -t flatpaks < <(etxe_package_list "$ETXE_FLATPAK_PACKAGES_FILE")
  [[ "${#flatpaks[@]}" -gt 0 ]] || return 0

  if etxe_has_flatpak_system_bundle; then
    etxe_log "Bundled Flatpak system found at $ETXE_FLATPAK_SYSTEM_ARCHIVE"
  elif [[ "${ETXE_REQUIRE_OFFLINE_FLATPAKS:-}" == "YES" ]]; then
    etxe_die "missing bundled Flatpak system at $ETXE_FLATPAK_SYSTEM_ARCHIVE"
  else
    etxe_log "No bundled Flatpak system found; Flatpak app installation requires internet"
  fi
}

etxe_preflight_offline_repo
