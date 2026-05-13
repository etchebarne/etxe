#!/usr/bin/env bash

etxe_configure_gnome_dconf() {
  etxe_log "Configuring GNOME defaults"

  local enabled_extensions_value=""
  local extension_uuid
  local -a enabled_extensions=()

  if declare -p ETXE_GNOME_ENABLED_EXTENSIONS >/dev/null 2>&1; then
    enabled_extensions=("${ETXE_GNOME_ENABLED_EXTENSIONS[@]}")
  fi

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

etxe_configure_gnome_dconf
