#!/usr/bin/env bash

etxe_require_var() {
  local name="$1"
  [[ -n "${!name:-}" ]] || etxe_die "$name is required"
}
