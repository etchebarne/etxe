#!/usr/bin/env bash

etxe_part_path() {
  local disk="$1"
  local number="$2"

  if [[ "$disk" =~ [0-9]$ ]]; then
    printf '%sp%s' "$disk" "$number"
  else
    printf '%s%s' "$disk" "$number"
  fi
}
