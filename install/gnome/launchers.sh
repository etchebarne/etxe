#!/usr/bin/env bash

etxe_install_gnome_launchers() {
  etxe_log "Installing GNOME launchers"

  install -d -m 0755 "$ETXE_MOUNT/usr/share/applications"
  cat >"$ETXE_MOUNT/usr/share/applications/etxe-log-out.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Log Out
Comment=End the current Etxe session
Exec=gnome-session-quit --logout
Icon=system-log-out-symbolic
Terminal=false
Categories=System;
OnlyShowIn=GNOME;
StartupNotify=false
EOF
}

etxe_install_gnome_launchers
