#!/usr/bin/env bash

ETXE_GNOME_ENABLED_EXTENSIONS=()

etxe_install_gnome_extensions() {
  etxe_log "Installing GNOME extensions"

  local extension_root="$ETXE_PATH/extensions"
  local extension_dest_root="$ETXE_MOUNT/usr/share/gnome-shell/extensions"
  local extension_dir extension_uuid extension_dest restore_nullglob

  [[ -d "$extension_root" ]] || return 0

  restore_nullglob="$(shopt -p nullglob || true)"
  shopt -s nullglob

  for extension_dir in "$extension_root"/*; do
    [[ -d "$extension_dir" ]] || continue
    [[ -f "$extension_dir/metadata.json" && -f "$extension_dir/extension.js" ]] || continue

    extension_uuid="${extension_dir##*/}"
    [[ "$extension_uuid" != *"'"* && "$extension_uuid" != */* ]] || etxe_die "invalid GNOME extension UUID: $extension_uuid"

    etxe_log "Installing GNOME extension $extension_uuid"
    extension_dest="$extension_dest_root/$extension_uuid"
    install -d -m 0755 "$extension_dest"
    cp -a "$extension_dir/." "$extension_dest/"
    if [[ -d "$extension_dest/schemas" ]]; then
      arch-chroot "$ETXE_MOUNT" glib-compile-schemas "/usr/share/gnome-shell/extensions/$extension_uuid/schemas"
    fi
    ETXE_GNOME_ENABLED_EXTENSIONS+=("$extension_uuid")
  done

  eval "$restore_nullglob"
}

etxe_install_gnome_extensions
