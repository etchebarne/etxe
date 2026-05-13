#!/usr/bin/env bash

etxe_configure_gnome() {
  etxe_log "Configuring GNOME defaults"

  local extension_root="$ETXE_PATH/extensions"
  local extension_dest_root="$ETXE_MOUNT/usr/share/gnome-shell/extensions"
  local extension_dir extension_uuid extension_dest enabled_extensions_value restore_nullglob
  local -a enabled_extensions=()

  if [[ -d "$extension_root" ]]; then
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
      enabled_extensions+=("$extension_uuid")
    done

    eval "$restore_nullglob"
  fi

  enabled_extensions_value=""
  for extension_uuid in "${enabled_extensions[@]}"; do
    if [[ -n "$enabled_extensions_value" ]]; then
      enabled_extensions_value+=", "
    fi
    enabled_extensions_value+="'$extension_uuid'"
  done

  install -d -m 0755 "$ETXE_MOUNT/etc/dconf/db/local.d" "$ETXE_MOUNT/etc/dconf/profile"
  cat >"$ETXE_MOUNT/etc/dconf/profile/user" <<'EOF'
user-db:user
system-db:local
EOF

  cat >"$ETXE_MOUNT/etc/dconf/db/local.d/00-etxe" <<'EOF'
[org/gnome/shell]
favorite-apps=['org.gnome.Nautilus.desktop', 'org.gnome.Console.desktop', 'firefox.desktop', 'org.gnome.TextEditor.desktop', 'org.gnome.Software.desktop', 'etxe-log-out.desktop']
EOF
  printf 'enabled-extensions=[%s]\n\n' "$enabled_extensions_value" >>"$ETXE_MOUNT/etc/dconf/db/local.d/00-etxe"
  cat >>"$ETXE_MOUNT/etc/dconf/db/local.d/00-etxe" <<'EOF'

[org/gnome/desktop/interface]
clock-show-weekday=true
enable-animations=true

[org/gnome/settings-daemon/plugins/housekeeping]
donation-reminder-enabled=false
EOF

  arch-chroot "$ETXE_MOUNT" dconf update
}

etxe_configure_gnome
