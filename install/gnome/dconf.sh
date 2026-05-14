#!/usr/bin/env bash

etxe_configure_gnome_dconf() {
  etxe_log "Configuring GNOME defaults"

  local enabled_extensions_value=""
  local extension_uuid
  local input_sources_value
  local keymap
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

  keymap="$(etxe_keyboard_current_keymap "$ETXE_MOUNT")"
  input_sources_value="$(etxe_keyboard_gnome_input_sources_value "$keymap" "$ETXE_MOUNT")"

  install -d -m 0755 "$ETXE_MOUNT/etc/dconf/db/local.d" "$ETXE_MOUNT/etc/dconf/db/gdm.d" "$ETXE_MOUNT/etc/dconf/profile"
  cat >"$ETXE_MOUNT/etc/dconf/profile/user" <<'EOF'
user-db:user
system-db:local
EOF
  cat >"$ETXE_MOUNT/etc/dconf/profile/gdm" <<'EOF'
user-db:user
system-db:gdm
file-db:/usr/share/gdm/greeter-dconf-defaults
EOF

  cat >"$ETXE_MOUNT/etc/dconf/db/local.d/00-etxe" <<'EOF'
[org/gnome/shell]
favorite-apps=['org.gnome.Nautilus.desktop', 'org.gnome.Console.desktop', 'firefox.desktop', 'org.gnome.TextEditor.desktop', 'org.gnome.Software.desktop']
always-show-log-out=true
EOF
  cat >"$ETXE_MOUNT/etc/dconf/db/gdm.d/00-etxe" <<'EOF'
[org/gnome/login-screen]
logo='/usr/share/pixmaps/etxe-logo.svg'
EOF
  printf 'enabled-extensions=[%s]\n\n' "$enabled_extensions_value" >>"$ETXE_MOUNT/etc/dconf/db/local.d/00-etxe"
  cat >>"$ETXE_MOUNT/etc/dconf/db/local.d/00-etxe" <<'EOF'

[org/gnome/login-screen]
logo='/usr/share/pixmaps/etxe-logo.svg'

[org/gnome/desktop/background]
picture-uri='file:///usr/share/backgrounds/etxe/etxe-light.png'
picture-uri-dark='file:///usr/share/backgrounds/etxe/etxe-dark.png'
picture-options='zoom'

[org/gnome/desktop/screensaver]
picture-uri='file:///usr/share/backgrounds/etxe/etxe-dark.png'
picture-options='zoom'

[org/gnome/desktop/interface]
clock-show-weekday=true
enable-animations=true

[org/gnome/shell/extensions/etxe-desktop]
show-home=false
EOF
  printf '[org/gnome/desktop/input-sources]\n' >>"$ETXE_MOUNT/etc/dconf/db/local.d/00-etxe"
  printf 'sources=[%s]\n' "$input_sources_value" >>"$ETXE_MOUNT/etc/dconf/db/local.d/00-etxe"
  printf 'mru-sources=[%s]\n' "$input_sources_value" >>"$ETXE_MOUNT/etc/dconf/db/local.d/00-etxe"
  printf 'current=uint32 0\n' >>"$ETXE_MOUNT/etc/dconf/db/local.d/00-etxe"
  printf 'show-all-sources=true\n\n' >>"$ETXE_MOUNT/etc/dconf/db/local.d/00-etxe"
  cat >>"$ETXE_MOUNT/etc/dconf/db/local.d/00-etxe" <<'EOF'

[org/gnome/settings-daemon/plugins/housekeeping]
donation-reminder-enabled=false
EOF

  arch-chroot "$ETXE_MOUNT" dconf update
}

etxe_configure_gnome_dconf
