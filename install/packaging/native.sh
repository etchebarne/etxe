#!/usr/bin/env bash

etxe_install_native_packages() {
  local -a packages
  local pacman_conf
  mapfile -t packages < <(etxe_package_list "$ETXE_NATIVE_PACKAGES_FILE")
  [[ "${#packages[@]}" -gt 0 ]] || etxe_die "no native packages found in $ETXE_NATIVE_PACKAGES_FILE"

  if etxe_has_offline_repo; then
    etxe_log "Installing native packages from offline repository"
    pacman_conf="$(mktemp)"
    cat >"$pacman_conf" <<EOF
[options]
Architecture = auto
CacheDir = $ETXE_OFFLINE_REPO
SigLevel = Never
LocalFileSigLevel = Optional
ParallelDownloads = 5

[etxe]
SigLevel = Never
Server = file://$ETXE_OFFLINE_REPO
EOF
    pacstrap -c -C "$pacman_conf" -K "$ETXE_MOUNT" "${packages[@]}"
    rm -f "$pacman_conf"
  else
    etxe_log "Installing native packages from online repositories"
    pacstrap -K "$ETXE_MOUNT" "${packages[@]}"
  fi
}

etxe_install_native_packages
