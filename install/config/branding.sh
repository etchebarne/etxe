#!/usr/bin/env bash

etxe_configure_branding() {
  etxe_log "Branding system as Etxe"

  install -D -m 0644 "$ETXE_PATH/assets/brand/etxe-icon.svg" \
    "$ETXE_MOUNT/usr/share/icons/hicolor/scalable/apps/etxe-icon.svg"
  install -D -m 0644 "$ETXE_PATH/assets/brand/etxe-logo.svg" \
    "$ETXE_MOUNT/usr/share/icons/hicolor/scalable/apps/etxe-logo.svg"
  install -D -m 0644 "$ETXE_PATH/assets/brand/etxe-logo.svg" \
    "$ETXE_MOUNT/usr/share/icons/hicolor/symbolic/apps/etxe-logo-symbolic.svg"
  sed -i 's/fill="white"/fill="#222222"/g' \
    "$ETXE_MOUNT/usr/share/icons/hicolor/symbolic/apps/etxe-logo-symbolic.svg"
  install -D -m 0644 "$ETXE_PATH/assets/brand/etxe-logo.svg" \
    "$ETXE_MOUNT/usr/share/pixmaps/etxe-logo.svg"

  if [[ -x "$ETXE_MOUNT/usr/bin/gtk-update-icon-cache" ]]; then
    arch-chroot "$ETXE_MOUNT" gtk-update-icon-cache -q -f /usr/share/icons/hicolor \
      || etxe_log "Icon cache update failed; continuing"
  fi

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
LOGO=etxe-logo-symbolic
EOF

  printf 'Etxe \\r (\\l)\n' >"$ETXE_MOUNT/etc/issue"
  printf 'Etxe\n' >"$ETXE_MOUNT/etc/issue.net"
}

etxe_configure_branding
