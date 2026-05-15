#!/usr/bin/env bash

etxe_install_welcome_app() {
  local app_source="$ETXE_PATH/apps/etxe-welcome"

  etxe_log "Installing Etxe welcome app"

  [[ -f "$app_source/etxe-welcome" ]] || etxe_die "missing Etxe welcome app"
  [[ -f "$app_source/local.etxe.Welcome.desktop" ]] || etxe_die "missing Etxe welcome launcher"
  [[ -f "$app_source/local.etxe.Welcome-symbolic.svg" ]] || etxe_die "missing Etxe welcome icon"
  [[ -f "$app_source/etxe-welcome.service" ]] || etxe_die "missing Etxe welcome user service"

  install -D -m 0755 "$app_source/etxe-welcome" \
    "$ETXE_MOUNT/usr/bin/etxe-welcome"
  install -D -m 0644 "$app_source/local.etxe.Welcome.desktop" \
    "$ETXE_MOUNT/usr/share/applications/local.etxe.Welcome.desktop"
  install -D -m 0644 "$app_source/local.etxe.Welcome-symbolic.svg" \
    "$ETXE_MOUNT/usr/share/icons/hicolor/symbolic/apps/local.etxe.Welcome-symbolic.svg"
  install -D -m 0644 "$app_source/etxe-welcome.service" \
    "$ETXE_MOUNT/usr/lib/systemd/user/etxe-welcome.service"

  if [[ -x "$ETXE_MOUNT/usr/bin/gtk-update-icon-cache" ]]; then
    arch-chroot "$ETXE_MOUNT" gtk-update-icon-cache -q -f /usr/share/icons/hicolor \
      || etxe_log "Icon cache update failed; continuing"
  fi

  arch-chroot "$ETXE_MOUNT" systemctl --global enable etxe-welcome.service
}

etxe_install_welcome_app
