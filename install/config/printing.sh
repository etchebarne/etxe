#!/usr/bin/env bash

etxe_configure_printing() {
  etxe_log "Configuring printing"

  arch-chroot "$ETXE_MOUNT" systemctl enable cups.service avahi-daemon.service ipp-usb.service

  if [[ -f "$ETXE_MOUNT/etc/nsswitch.conf" ]] && ! grep -Eq '^hosts:.*[[:space:]]mdns_minimal([[:space:]]|$)' "$ETXE_MOUNT/etc/nsswitch.conf"; then
    sed -i -E '/^hosts:/ {
      s/[[:space:]]+resolve([[:space:]]+\[!UNAVAIL=return\])?/ mdns_minimal [NOTFOUND=return]&/
      t
      s/[[:space:]]+dns/ mdns_minimal [NOTFOUND=return]&/
      t
      s/$/ mdns_minimal [NOTFOUND=return]/
    }' "$ETXE_MOUNT/etc/nsswitch.conf"
  fi
}

etxe_configure_printing
