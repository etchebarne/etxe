#!/usr/bin/env bash

etxe_configure_branding() {
  etxe_log "Branding system as Etxe"

  install -D -m 0644 "$ETXE_PATH/assets/brand/etxe-icon.svg" \
    "$ETXE_MOUNT/usr/share/icons/hicolor/scalable/apps/etxe-icon.svg"
  install -D -m 0644 "$ETXE_PATH/assets/brand/etxe-icon-symbolic.svg" \
    "$ETXE_MOUNT/usr/share/icons/hicolor/scalable/apps/etxe-icon-symbolic.svg"
  install -D -m 0644 "$ETXE_PATH/assets/brand/etxe-icon-symbolic.svg" \
    "$ETXE_MOUNT/usr/share/icons/hicolor/symbolic/apps/etxe-icon-symbolic.svg"

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

  rm -f "$ETXE_MOUNT/etc/os-release"
  cat >"$ETXE_MOUNT/etc/os-release" <<'EOF'
NAME="Etxe"
PRETTY_NAME="Etxe"
ID=arch
BUILD_ID=rolling
ANSI_COLOR="38;2;23;147;209"
HOME_URL="https://archlinux.org/"
DOCUMENTATION_URL="https://wiki.archlinux.org/"
SUPPORT_URL="https://bbs.archlinux.org/"
BUG_REPORT_URL="https://gitlab.archlinux.org/groups/archlinux/-/issues"
PRIVACY_POLICY_URL="https://terms.archlinux.org/docs/privacy-policy/"
LOGO=etxe-icon-symbolic
EOF

  printf 'Etxe \\r (\\l)\n' >"$ETXE_MOUNT/etc/issue"
  printf 'Etxe\n' >"$ETXE_MOUNT/etc/issue.net"
}

etxe_configure_branding
