#!/usr/bin/env bash

etxe_die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

etxe_log() {
  printf '==> %s\n' "$*"
}

etxe_start_log() {
  local log_dir
  [[ "${ETXE_LOG_STARTED:-}" == "YES" ]] && return 0

  log_dir="$(dirname -- "$ETXE_INSTALL_LOG_FILE")"

  install -d -m 0755 "$log_dir"
  touch "$ETXE_INSTALL_LOG_FILE"
  chmod 0644 "$ETXE_INSTALL_LOG_FILE"
  export ETXE_LOG_STARTED=YES
  exec > >(tee -a "$ETXE_INSTALL_LOG_FILE") 2>&1
}
