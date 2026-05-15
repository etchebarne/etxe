#!/bin/bash

set -eEo pipefail

export ETXE_PATH="${ETXE_PATH:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)}"
export ETXE_INSTALL="$ETXE_PATH/install"
export ETXE_LOG_FILE="${ETXE_LOG_FILE:-${ETXE_UPDATE_LOG_FILE:-/var/log/etxe-update.log}}"

ETXE_NATIVE_PACKAGES_FILE="${ETXE_NATIVE_PACKAGES_FILE:-$ETXE_PATH/packages/native.pkglist}"
ETXE_FLATPAK_PACKAGES_FILE="${ETXE_FLATPAK_PACKAGES_FILE:-$ETXE_PATH/packages/flatpak.pkglist}"
ETXE_SYSTEM_PATH="${ETXE_SYSTEM_PATH:-/opt/etxe}"
ETXE_UPDATE_ASSUME_YES="${ETXE_UPDATE_ASSUME_YES:-YES}"
ETXE_UPDATE_INSTALL_SYSTEM_COPY="${ETXE_UPDATE_INSTALL_SYSTEM_COPY:-YES}"

source "$ETXE_INSTALL/helpers/logging.sh"
source "$ETXE_INSTALL/helpers/keyboard.sh"
source "$ETXE_INSTALL/helpers/packages.sh"
source "$ETXE_INSTALL/helpers/payload.sh"

etxe_update_require_root() {
  [[ "${EUID:-$(id -u)}" -eq 0 ]] || etxe_die "run as root"
}

etxe_update_require_installed_etxe() {
  [[ "${ETXE_UPDATE_FORCE:-NO}" == "YES" ]] && return 0

  if [[ -r /etc/os-release ]] && grep -Eq '^(NAME|PRETTY_NAME)="?Etxe"?$' /etc/os-release; then
    return 0
  fi

  etxe_die "this does not look like an installed Etxe system; set ETXE_UPDATE_FORCE=YES to override"
}

etxe_update_require_command() {
  local command

  for command in "$@"; do
    command -v "$command" >/dev/null || etxe_die "$command is required"
  done
}

etxe_update_preflight() {
  [[ -f "$ETXE_NATIVE_PACKAGES_FILE" ]] || etxe_die "missing native package list: $ETXE_NATIVE_PACKAGES_FILE"
  [[ -f "$ETXE_FLATPAK_PACKAGES_FILE" ]] || etxe_die "missing Flatpak package list: $ETXE_FLATPAK_PACKAGES_FILE"
  [[ -d "$ETXE_PATH/extensions" ]] || etxe_log "No GNOME extensions directory found at $ETXE_PATH/extensions"

  etxe_update_require_command grep install pacman sed tar
}

etxe_update_pacman_args() {
  printf '%s\0' -Syu --needed
  [[ "$ETXE_UPDATE_ASSUME_YES" == "YES" ]] && printf '%s\0' --noconfirm
}

etxe_update_native_packages() {
  local -a packages pacman_args

  mapfile -t packages < <(etxe_package_list "$ETXE_NATIVE_PACKAGES_FILE")
  [[ "${#packages[@]}" -gt 0 ]] || etxe_die "no native packages found in $ETXE_NATIVE_PACKAGES_FILE"

  mapfile -d '' -t pacman_args < <(etxe_update_pacman_args)

  etxe_log "Updating native packages"
  pacman "${pacman_args[@]}" "${packages[@]}"
}

etxe_update_flatpaks() {
  local -a flatpaks

  mapfile -t flatpaks < <(etxe_package_list "$ETXE_FLATPAK_PACKAGES_FILE")
  [[ "${#flatpaks[@]}" -gt 0 ]] || return 0

  etxe_update_require_command flatpak

  etxe_log "Updating Flatpak apps"
  flatpak remote-add --system --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  flatpak install --system --noninteractive --assumeyes --or-update flathub "${flatpaks[@]}"
  flatpak update --system --noninteractive --assumeyes
}

etxe_configure_printing() {
  etxe_log "Updating printing services"

  systemctl enable --now cups.service avahi-daemon.service ipp-usb.service

  if [[ -f /etc/nsswitch.conf ]] && ! grep -Eq '^hosts:.*[[:space:]]mdns_minimal([[:space:]]|$)' /etc/nsswitch.conf; then
    sed -i -E '/^hosts:/ {
      s/[[:space:]]+resolve([[:space:]]+\[!UNAVAIL=return\])?/ mdns_minimal [NOTFOUND=return]&/
      t
      s/[[:space:]]+dns/ mdns_minimal [NOTFOUND=return]&/
      t
      s/$/ mdns_minimal [NOTFOUND=return]/
    }' /etc/nsswitch.conf
  fi
}

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
  etxe_update_require_command msgfmt

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
  local extension_root="$ETXE_PATH/extensions"
  local extension_dest_root="/usr/share/gnome-shell/extensions"
  local extension_dir extension_uuid extension_dest restore_nullglob

  ETXE_GNOME_ENABLED_EXTENSIONS=()

  [[ -d "$extension_root" ]] || return 0
  etxe_update_require_command glib-compile-schemas

  etxe_log "Updating GNOME extensions"

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
    etxe_compile_gnome_extension_translations "$extension_dest"
    if [[ -d "$extension_dest/schemas" ]]; then
      glib-compile-schemas "$extension_dest/schemas"
    fi
    ETXE_GNOME_ENABLED_EXTENSIONS+=("$extension_uuid")
  done

  etxe_prune_removed_gnome_extensions "$extension_dest_root"

  eval "$restore_nullglob"
}

etxe_gnome_extension_is_current() {
  local extension_uuid="$1"
  local current_uuid

  for current_uuid in "${ETXE_GNOME_ENABLED_EXTENSIONS[@]}"; do
    [[ "$current_uuid" == "$extension_uuid" ]] && return 0
  done

  return 1
}

etxe_prune_removed_gnome_extensions() {
  local extension_dest_root="$1"
  local extension_dest extension_uuid

  for extension_dest in "$extension_dest_root"/*@etxe.local; do
    [[ -d "$extension_dest" ]] || continue

    extension_uuid="${extension_dest##*/}"
    if ! etxe_gnome_extension_is_current "$extension_uuid"; then
      etxe_log "Removing old GNOME extension $extension_uuid"
      rm -rf "$extension_dest"
    fi
  done
}

etxe_hide_gnome_app_grid_launchers() {
  local hidden_launchers="$ETXE_INSTALL/gnome/hidden-app-grid-launchers.sh"
  local launcher_id
  local -a ETXE_HIDDEN_APP_GRID_LAUNCHERS=()

  [[ -f "$hidden_launchers" ]] || return 0

  etxe_log "Updating hidden app-grid launchers"
  source "$hidden_launchers"
  install -d -m 0755 /usr/local/share/applications

  for launcher_id in "${ETXE_HIDDEN_APP_GRID_LAUNCHERS[@]}"; do
    [[ -n "$launcher_id" && "$launcher_id" != */* ]] || etxe_die "invalid hidden app-grid launcher ID: $launcher_id"

    cat >"/usr/local/share/applications/$launcher_id" <<EOF
[Desktop Entry]
Type=Application
Name=$launcher_id
NoDisplay=true
Hidden=true
EOF
  done
}

etxe_install_welcome_app() {
  local app_source="$ETXE_PATH/apps/etxe-welcome"

  [[ -f "$app_source/etxe-welcome" ]] || etxe_die "missing Etxe welcome app"
  [[ -f "$app_source/local.etxe.Welcome.desktop" ]] || etxe_die "missing Etxe welcome launcher"
  [[ -f "$app_source/local.etxe.Welcome-symbolic.svg" ]] || etxe_die "missing Etxe welcome icon"
  [[ -f "$app_source/etxe-welcome.service" ]] || etxe_die "missing Etxe welcome user service"

  etxe_log "Updating Etxe welcome app"

  install -D -m 0755 "$app_source/etxe-welcome" /usr/bin/etxe-welcome
  install -D -m 0644 "$app_source/local.etxe.Welcome.desktop" \
    /usr/share/applications/local.etxe.Welcome.desktop
  install -D -m 0644 "$app_source/local.etxe.Welcome-symbolic.svg" \
    /usr/share/icons/hicolor/symbolic/apps/local.etxe.Welcome-symbolic.svg
  install -D -m 0644 "$app_source/etxe-welcome.service" \
    /usr/lib/systemd/user/etxe-welcome.service

  if command -v gtk-update-icon-cache >/dev/null; then
    gtk-update-icon-cache -q -f /usr/share/icons/hicolor \
      || etxe_log "Icon cache update failed; continuing"
  fi

  systemctl --global enable etxe-welcome.service
}

etxe_configure_gnome_dconf() {
  local enabled_extensions_value=""
  local extension_uuid
  local input_sources_value
  local keymap

  etxe_update_require_command dconf

  etxe_log "Updating GNOME defaults"

  for extension_uuid in "${ETXE_GNOME_ENABLED_EXTENSIONS[@]}"; do
    if [[ -n "$enabled_extensions_value" ]]; then
      enabled_extensions_value+=", "
    fi
    enabled_extensions_value+="'$extension_uuid'"
  done

  keymap="$(etxe_keyboard_current_keymap)"
  input_sources_value="$(etxe_keyboard_gnome_input_sources_value "$keymap")"

  install -d -m 0755 /etc/dconf/db/local.d /etc/dconf/db/gdm.d /etc/dconf/profile
  cat >/etc/dconf/profile/user <<'EOF'
user-db:user
system-db:local
EOF
  cat >/etc/dconf/profile/gdm <<'EOF'
user-db:user
system-db:gdm
file-db:/usr/share/gdm/greeter-dconf-defaults
EOF

  cat >/etc/dconf/db/local.d/00-etxe <<'EOF'
[org/gnome/shell]
favorite-apps=['org.gnome.Nautilus.desktop', 'firefox.desktop', 'org.gnome.Software.desktop']
always-show-log-out=true
EOF
  cat >/etc/dconf/db/gdm.d/00-etxe <<'EOF'
[org/gnome/login-screen]
logo='/usr/share/pixmaps/etxe-logo.svg'
EOF
  printf 'enabled-extensions=[%s]\n\n' "$enabled_extensions_value" >>/etc/dconf/db/local.d/00-etxe
  cat >>/etc/dconf/db/local.d/00-etxe <<'EOF'

[org/gnome/login-screen]
logo='/usr/share/pixmaps/etxe-logo.svg'

[org/gnome/desktop/background]
picture-uri='file:///usr/share/backgrounds/etxe/etxe-light.png'
picture-uri-dark='file:///usr/share/backgrounds/etxe/etxe-dark.png'
picture-options='zoom'

[org/gnome/desktop/screensaver]
picture-uri='file:///usr/share/backgrounds/etxe/etxe-dark.png'
picture-options='zoom'

[org/gnome/desktop/interface]
clock-show-weekday=true
enable-animations=true

[org/gnome/shell/extensions/etxe-desktop]
show-home=false
EOF
  printf '[org/gnome/desktop/input-sources]\n' >>/etc/dconf/db/local.d/00-etxe
  printf 'sources=[%s]\n' "$input_sources_value" >>/etc/dconf/db/local.d/00-etxe
  printf 'mru-sources=[%s]\n' "$input_sources_value" >>/etc/dconf/db/local.d/00-etxe
  printf 'current=uint32 0\n' >>/etc/dconf/db/local.d/00-etxe
  printf 'show-all-sources=true\n\n' >>/etc/dconf/db/local.d/00-etxe
  cat >>/etc/dconf/db/local.d/00-etxe <<'EOF'

[org/gnome/settings-daemon/plugins/housekeeping]
donation-reminder-enabled=false
EOF

  dconf update
}

etxe_update_branding() {
  etxe_log "Updating Etxe branding"

  local background_file

  install -D -m 0644 "$ETXE_PATH/assets/brand/etxe-icon.svg" \
    /usr/share/icons/hicolor/scalable/apps/etxe-icon.svg
  install -D -m 0644 "$ETXE_PATH/assets/brand/etxe-logo.svg" \
    /usr/share/icons/hicolor/scalable/apps/etxe-logo.svg
  install -D -m 0644 "$ETXE_PATH/assets/brand/etxe-logo.svg" \
    /usr/share/icons/hicolor/symbolic/apps/etxe-logo-symbolic.svg
  sed -i 's/fill="white"/fill="#222222"/g' \
    /usr/share/icons/hicolor/symbolic/apps/etxe-logo-symbolic.svg
  install -D -m 0644 "$ETXE_PATH/assets/brand/etxe-logo.svg" \
    /usr/share/pixmaps/etxe-logo.svg

  for background_file in "$ETXE_PATH"/assets/backgrounds/*; do
    [[ -f "$background_file" ]] || continue
    install -D -m 0644 "$background_file" \
      "/usr/share/backgrounds/etxe/${background_file##*/}"
  done

  rm -f \
    /usr/share/icons/hicolor/scalable/apps/etxe-icon-symbolic.svg \
    /usr/share/icons/hicolor/symbolic/apps/etxe-icon-symbolic.svg

  if command -v gtk-update-icon-cache >/dev/null; then
    gtk-update-icon-cache -q -f /usr/share/icons/hicolor \
      || etxe_log "Icon cache update failed; continuing"
  fi

  rm -f /etc/os-release
  cat >/etc/os-release <<'EOF'
NAME="Etxe"
PRETTY_NAME="Etxe"
ID=arch
BUILD_ID=rolling
ANSI_COLOR="38;2;23;147;209"
HOME_URL="https://archlinux.org/"
DOCUMENTATION_URL="https://wiki.archlinux.org/"
SUPPORT_URL="https://bbs.archlinux.org/"
BUG_REPORT_URL="https://gitlab.archlinux.org/groups/archlinux/-/issues"
PRIVACY_POLICY_URL="https://terms.archlinux.org/docs/privacy-policy/"
LOGO=etxe-logo-symbolic
EOF

  printf 'Etxe \\r (\\l)\n' >/etc/issue
  printf 'Etxe\n' >/etc/issue.net
}

etxe_update_systemd_boot() {
  command -v bootctl >/dev/null || return 0
  bootctl is-installed --quiet >/dev/null 2>&1 || return 0

  etxe_log "Updating systemd-boot"
  bootctl update || etxe_log "systemd-boot update failed; continuing"
}

etxe_install_system_copy() {
  local source_real target_parent target_real temp_dir

  [[ "$ETXE_UPDATE_INSTALL_SYSTEM_COPY" == "YES" ]] || return 0
  [[ -n "$ETXE_SYSTEM_PATH" && "$ETXE_SYSTEM_PATH" == /* && "$ETXE_SYSTEM_PATH" != "/" ]] \
    || etxe_die "ETXE_SYSTEM_PATH must be an absolute path below /"

  source_real="$(realpath -m "$ETXE_PATH")"
  target_real="$(realpath -m "$ETXE_SYSTEM_PATH")"
  [[ "$source_real" != "$target_real" ]] || return 0

  etxe_log "Installing update payload to $ETXE_SYSTEM_PATH"

  target_parent="$(dirname -- "$ETXE_SYSTEM_PATH")"
  install -d -m 0755 "$target_parent"
  temp_dir="$(mktemp -d "$target_parent/.etxe-update.XXXXXX")"

  etxe_archive_repo_to "$temp_dir"
  chmod +x "$temp_dir/update.sh"
  rm -rf "$ETXE_SYSTEM_PATH"
  mv "$temp_dir" "$ETXE_SYSTEM_PATH"
}

etxe_install_update_command() {
  [[ "$ETXE_UPDATE_INSTALL_SYSTEM_COPY" == "YES" ]] || return 0

  etxe_log "Installing etxe-update command"

  etxe_write_update_command /usr/local/bin/etxe-update "$ETXE_SYSTEM_PATH"
}

etxe_update_require_root
etxe_update_require_installed_etxe
etxe_start_log
etxe_update_preflight
etxe_update_native_packages
etxe_configure_printing
etxe_update_flatpaks
etxe_install_gnome_extensions
etxe_hide_gnome_app_grid_launchers
etxe_install_welcome_app
etxe_configure_gnome_dconf
etxe_update_branding
etxe_update_systemd_boot
etxe_install_system_copy
etxe_install_update_command
etxe_log "Etxe update finished successfully"
