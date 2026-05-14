#!/usr/bin/env bash

etxe_keyboard_path() {
  local root="${1:-/}"
  local path="$2"

  if [[ "$root" == "/" ]]; then
    printf '%s\n' "$path"
  else
    printf '%s%s\n' "${root%/}" "$path"
  fi
}

etxe_keyboard_current_keymap() {
  local root="${1:-/}"
  local vconsole
  local name value

  if [[ -n "${KEYMAP:-}" ]]; then
    printf '%s\n' "$KEYMAP"
    return 0
  fi

  vconsole="$(etxe_keyboard_path "$root" /etc/vconsole.conf)"
  if [[ -r "$vconsole" ]]; then
    while IFS='=' read -r name value; do
      [[ "$name" == "KEYMAP" ]] || continue
      value="${value%\"}"
      value="${value#\"}"
      value="${value%\'}"
      value="${value#\'}"
      printf '%s\n' "$value"
      return 0
    done <"$vconsole"
  fi

  printf 'us\n'
}

etxe_keyboard_gnome_input_sources_value() {
  local keymap="${1:-us}"
  local root="${2:-/}"
  local model_map
  local console_layout xlayouts _xmodel xvariants _xoptions
  local layout variant source separator
  local index
  local -a layouts=()
  local -a variants=()
  local -a sources=()
  local -A seen=()

  model_map="$(etxe_keyboard_path "$root" /usr/share/systemd/kbd-model-map)"
  xlayouts=""
  xvariants=""

  if [[ -r "$model_map" ]]; then
    while read -r console_layout xlayouts _xmodel xvariants _xoptions; do
      if [[ -z "$console_layout" || "$console_layout" == \#* ]]; then
        xlayouts=""
        xvariants=""
        continue
      fi

      if [[ "$console_layout" == "$keymap" ]]; then
        break
      fi

      xlayouts=""
      xvariants=""
    done <"$model_map"
  fi

  if [[ -z "$xlayouts" ]]; then
    xlayouts="${keymap%%-*}"
    xvariants="-"
  fi

  IFS=',' read -r -a layouts <<<"$xlayouts"
  IFS=',' read -r -a variants <<<"$xvariants"

  for index in "${!layouts[@]}"; do
    layout="${layouts[$index]}"
    variant="${variants[$index]:-}"
    [[ -n "$layout" && "$layout" != "-" ]] || continue

    if [[ -n "$variant" && "$variant" != "-" ]]; then
      source="$layout+$variant"
    else
      source="$layout"
    fi

    if [[ -z "${seen[$source]+x}" ]]; then
      sources+=("$source")
      seen[$source]=1
    fi
  done

  if [[ -z "${seen[us]+x}" ]]; then
    sources+=("us")
  fi

  separator=""
  for source in "${sources[@]}"; do
    printf "%s('xkb', '%s')" "$separator" "$source"
    separator=", "
  done
}
