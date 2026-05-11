#!/usr/bin/env bash

etxe_configure_autologin() {
  [[ "${ETXE_AUTOLOGIN:-}" == "YES" ]] || return 0

  etxe_log "Enabling GDM autologin for $USERNAME"
  install -d -m 0755 "$ETXE_MOUNT/etc/gdm" "$ETXE_MOUNT/var/lib/AccountsService/users"
  cat >"$ETXE_MOUNT/etc/gdm/custom.conf" <<EOF
[daemon]
AutomaticLoginEnable=True
AutomaticLogin=$USERNAME
EOF

  cat >"$ETXE_MOUNT/var/lib/AccountsService/users/$USERNAME" <<'EOF'
[User]
Session=gnome
EOF
}

etxe_configure_autologin
