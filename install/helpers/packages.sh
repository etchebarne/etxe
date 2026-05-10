#!/usr/bin/env bash

etxe_package_list() {
  local file="$1"
  grep -Ev '^[[:space:]]*(#|$)' "$file" || true
}

etxe_has_offline_repo() {
  [[ -f "$ETXE_OFFLINE_REPO/etxe.db" || -f "$ETXE_OFFLINE_REPO/etxe.db.tar.zst" ]]
}

etxe_has_flatpak_system_bundle() {
  [[ -f "$ETXE_FLATPAK_SYSTEM_ARCHIVE" ]]
}
