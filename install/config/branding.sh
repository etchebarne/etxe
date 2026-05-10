#!/usr/bin/env bash

etxe_configure_branding() {
  etxe_log "Branding system as Etxe"

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
LOGO=archlinux-logo
EOF

  printf 'Etxe \\r (\\l)\n' >"$ETXE_MOUNT/etc/issue"
  printf 'Etxe\n' >"$ETXE_MOUNT/etc/issue.net"
}

etxe_configure_branding
