#!/usr/bin/env bash

ETXE_GNOME_ENABLED_EXTENSIONS=("dash-to-panel@jderose9.github.com")

etxe_gnome_extension_gettext_domain() {
  local metadata="$1"
  local line

  while IFS= read -r line; do
    if [[ "$line" =~ \"gettext-domain\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
      printf '%s\n' "${BASH_REMATCH[1]}"
      return 0
    fi
  done <"$metadata"
}

etxe_compile_gnome_extension_translations() {
  local extension_dest="$1"
  local linguas="$extension_dest/po/LINGUAS"
  local domain lang output_dir

  [[ -f "$linguas" ]] || return 0

  domain="$(etxe_gnome_extension_gettext_domain "$extension_dest/metadata.json")"
  [[ -n "$domain" && "$domain" != */* && "$domain" != *..* ]] || etxe_die "invalid gettext domain for ${extension_dest##*/}"

  rm -rf "$extension_dest/locale"

  while IFS= read -r lang; do
    [[ -n "$lang" && "$lang" != \#* ]] || continue
    [[ "$lang" != */* && "$lang" != *..* ]] || etxe_die "invalid locale $lang for ${extension_dest##*/}"
    [[ -f "$extension_dest/po/$lang.po" ]] || etxe_die "missing $lang translation for ${extension_dest##*/}"

    output_dir="$extension_dest/locale/$lang/LC_MESSAGES"
    install -d -m 0755 "$output_dir"
    msgfmt -c -o "$output_dir/$domain.mo" "$extension_dest/po/$lang.po"
  done <"$linguas"
}

etxe_install_gnome_extensions() {
  etxe_log "Installing GNOME extensions"

  local extension_root="$ETXE_PATH/extensions"
  local extension_dest_root="$ETXE_MOUNT/usr/share/gnome-shell/extensions"
  local extension_dir extension_uuid extension_dest restore_nullglob

  [[ -d "$extension_root" ]] || return 0

  restore_nullglob="$(shopt -p nullglob || true)"
  shopt -s nullglob

  for extension_dir in "$extension_root"/*; do
    [[ -d "$extension_dir" ]] || continue
    [[ -f "$extension_dir/metadata.json" && -f "$extension_dir/extension.js" ]] || continue

    extension_uuid="${extension_dir##*/}"
    [[ "$extension_uuid" != *"'"* && "$extension_uuid" != */* ]] || etxe_die "invalid GNOME extension UUID: $extension_uuid"

    etxe_log "Installing GNOME extension $extension_uuid"
    extension_dest="$extension_dest_root/$extension_uuid"
    rm -rf "$extension_dest"
    install -d -m 0755 "$extension_dest"
    cp -a "$extension_dir/." "$extension_dest/"
    [[ ! -f "$extension_dest/app/ding.js" ]] || chmod 0755 "$extension_dest/app/ding.js"
    [[ ! -f "$extension_dest/app/createThumbnail.js" ]] || chmod 0755 "$extension_dest/app/createThumbnail.js"
    etxe_compile_gnome_extension_translations "$extension_dest"
    if [[ -d "$extension_dest/schemas" ]]; then
      arch-chroot "$ETXE_MOUNT" glib-compile-schemas "/usr/share/gnome-shell/extensions/$extension_uuid/schemas"
      [[ -f "$extension_dest/schemas/gschemas.compiled" ]] \
        || etxe_die "failed to compile GNOME extension schemas for $extension_uuid"
    fi
    ETXE_GNOME_ENABLED_EXTENSIONS+=("$extension_uuid")
  done

  eval "$restore_nullglob"
}

etxe_install_gnome_extensions
