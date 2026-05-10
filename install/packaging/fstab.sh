#!/usr/bin/env bash

etxe_generate_fstab() {
  etxe_log "Generating fstab"
  genfstab -U "$ETXE_MOUNT" >>"$ETXE_MOUNT/etc/fstab"
}

etxe_generate_fstab
