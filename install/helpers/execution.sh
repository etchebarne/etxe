#!/usr/bin/env bash

etxe_run() {
  local script="$1"
  [[ -f "$script" ]] || etxe_die "missing install step: $script"
  source "$script"
}
