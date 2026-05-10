#!/usr/bin/env bash

etxe_finish_install() {
  etxe_log "Installation finished successfully"

  case "$ETXE_FINISH_ACTION" in
    poweroff)
      etxe_log "Powering off in 10 seconds"
      sync
      sleep 10
      systemctl poweroff
      ;;
    reboot)
      etxe_log "Rebooting in 10 seconds"
      sync
      sleep 10
      systemctl reboot
      ;;
    none)
      etxe_log "Leaving live ISO running"
      ;;
    *)
      etxe_die "unknown ETXE_FINISH_ACTION: $ETXE_FINISH_ACTION"
      ;;
  esac
}

etxe_finish_install
