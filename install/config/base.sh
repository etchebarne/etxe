#!/usr/bin/env bash

etxe_configure_base_system() {
  etxe_log "Configuring locale, timezone, and hostname"

  arch-chroot "$ETXE_MOUNT" ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
  arch-chroot "$ETXE_MOUNT" hwclock --systohc

  if grep -q "^#$LOCALE UTF-8" "$ETXE_MOUNT/etc/locale.gen"; then
    sed -i "s/^#\($LOCALE UTF-8\)/\1/" "$ETXE_MOUNT/etc/locale.gen"
  elif ! grep -q "^$LOCALE UTF-8" "$ETXE_MOUNT/etc/locale.gen"; then
    printf '%s UTF-8\n' "$LOCALE" >>"$ETXE_MOUNT/etc/locale.gen"
  fi

  arch-chroot "$ETXE_MOUNT" locale-gen
  printf 'LANG=%s\n' "$LOCALE" >"$ETXE_MOUNT/etc/locale.conf"
  if [[ -n "${KEYMAP:-}" ]]; then
    printf 'KEYMAP=%s\n' "$KEYMAP" >"$ETXE_MOUNT/etc/vconsole.conf"
  fi
  printf '%s\n' "$HOSTNAME" >"$ETXE_MOUNT/etc/hostname"

  cat >"$ETXE_MOUNT/etc/hosts" <<EOF
127.0.0.1 localhost
::1 localhost
127.0.1.1 $HOSTNAME.localdomain $HOSTNAME
EOF
}

etxe_configure_base_system
