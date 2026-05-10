#!/usr/bin/env bash

etxe_configure_autologin() {
  [[ "${ETXE_AUTOLOGIN:-}" == "YES" ]] || return 0

  etxe_log "Enabling SDDM autologin for $USERNAME"
  install -d -m 0755 "$ETXE_MOUNT/etc/sddm.conf.d"
  cat >"$ETXE_MOUNT/etc/sddm.conf.d/10-etxe-autologin.conf" <<EOF
[Autologin]
User=$USERNAME
Session=plasma
EOF
}

etxe_configure_autologin
