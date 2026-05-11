#!/usr/bin/env bash

etxe_configure_gnome() {
  etxe_log "Configuring GNOME defaults"

  install -d -m 0755 "$ETXE_MOUNT/etc/dconf/db/local.d" "$ETXE_MOUNT/etc/dconf/profile"
  cat >"$ETXE_MOUNT/etc/dconf/profile/user" <<'EOF'
user-db:user
system-db:local
EOF

  cat >"$ETXE_MOUNT/etc/dconf/db/local.d/00-etxe" <<'EOF'
[org/gnome/shell]
favorite-apps=['org.gnome.Nautilus.desktop', 'org.gnome.Console.desktop', 'firefox.desktop', 'org.gnome.TextEditor.desktop', 'org.gnome.Software.desktop']

[org/gnome/desktop/interface]
clock-show-weekday=true
EOF

  arch-chroot "$ETXE_MOUNT" dconf update
}

etxe_configure_gnome
