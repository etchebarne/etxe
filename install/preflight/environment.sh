#!/usr/bin/env bash

etxe_preflight_environment() {
  [[ "${EUID:-$(id -u)}" -eq 0 ]] || etxe_die "run as root"

  etxe_start_log
  etxe_log "Running preflight checks"

  etxe_require_var DISK
  etxe_require_var HOSTNAME
  etxe_require_var USERNAME
  etxe_require_var TIMEZONE
  etxe_require_var LOCALE
  etxe_require_var CONFIRM_WIPE

  [[ "$CONFIRM_WIPE" == "YES" ]] || etxe_die "CONFIRM_WIPE must be YES"
  [[ -b "$DISK" ]] || etxe_die "$DISK is not a block device"
}

etxe_preflight_environment
