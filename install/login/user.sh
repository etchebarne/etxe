#!/usr/bin/env bash

etxe_configure_user() {
  etxe_log "Creating user $USERNAME"

  arch-chroot "$ETXE_MOUNT" useradd -m -G wheel -s /bin/bash "$USERNAME"

  if [[ -n "${USER_PASSWORD:-}" ]]; then
    etxe_log "Setting password for $USERNAME"
    printf '%s:%s\n' "$USERNAME" "$USER_PASSWORD" | arch-chroot "$ETXE_MOUNT" chpasswd
  fi

  install -d -m 0755 "$ETXE_MOUNT/etc/sudoers.d"
  printf '%%wheel ALL=(ALL:ALL) ALL\n' >"$ETXE_MOUNT/etc/sudoers.d/10-wheel"
  chmod 0440 "$ETXE_MOUNT/etc/sudoers.d/10-wheel"
}

etxe_configure_user
