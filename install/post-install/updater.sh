#!/usr/bin/env bash

etxe_install_updater_payload() {
  local target="$ETXE_MOUNT/opt/etxe"
  local temp_dir

  etxe_log "Installing Etxe updater"

  install -d -m 0755 "$ETXE_MOUNT/opt"
  temp_dir="$(mktemp -d "$ETXE_MOUNT/opt/.etxe-update.XXXXXX")"

  etxe_archive_repo_to "$temp_dir"
  chmod +x "$temp_dir/update.sh"
  rm -rf "$target"
  mv "$temp_dir" "$target"

  etxe_write_update_command "$ETXE_MOUNT/usr/local/bin/etxe-update" /opt/etxe
}

etxe_install_updater_payload
