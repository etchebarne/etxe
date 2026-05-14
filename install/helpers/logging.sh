#!/usr/bin/env bash

etxe_die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

etxe_log() {
  printf '==> %s\n' "$*"
}

etxe_start_log() {
  local log_dir log_file
  [[ "${ETXE_LOG_STARTED:-}" == "YES" ]] && return 0

  log_file="${ETXE_LOG_FILE:-${ETXE_INSTALL_LOG_FILE:-}}"
  [[ -n "$log_file" ]] || etxe_die "ETXE_LOG_FILE is required"
  export ETXE_LOG_FILE="$log_file"

  log_dir="$(dirname -- "$log_file")"

  install -d -m 0755 "$log_dir"
  touch "$log_file"
  chmod 0644 "$log_file"
  export ETXE_LOG_STARTED=YES
  exec > >(tee -a "$log_file") 2>&1
}
