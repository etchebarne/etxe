#!/usr/bin/env bash

etxe_configure_audio() {
  etxe_log "Configuring PipeWire"
  arch-chroot "$ETXE_MOUNT" systemctl --global enable pipewire.service pipewire-pulse.service wireplumber.service
}

etxe_configure_audio
