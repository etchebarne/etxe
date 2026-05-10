#!/usr/bin/env bash

etxe_preflight_offline_repo() {
  if [[ "${ETXE_REQUIRE_OFFLINE_REPO:-}" == "YES" ]]; then
    etxe_has_offline_repo || etxe_die "missing offline repository at $ETXE_OFFLINE_REPO"
  fi

  if etxe_has_offline_repo; then
    etxe_log "Offline repository found at $ETXE_OFFLINE_REPO"
  else
    etxe_log "No offline repository found; package installation requires internet"
  fi
}

etxe_preflight_offline_repo
