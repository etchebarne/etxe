#!/usr/bin/env bash

etxe_hide_gnome_app_grid_launchers() {
  etxe_log "Hiding utility launchers from GNOME app grid"

  local hidden_launchers="$ETXE_INSTALL/gnome/hidden-app-grid-launchers.sh"
  local launcher_id
  local -a ETXE_HIDDEN_APP_GRID_LAUNCHERS=()

  [[ -f "$hidden_launchers" ]] || return 0

  source "$hidden_launchers"
  install -d -m 0755 "$ETXE_MOUNT/usr/local/share/applications"

  for launcher_id in "${ETXE_HIDDEN_APP_GRID_LAUNCHERS[@]}"; do
    [[ -n "$launcher_id" && "$launcher_id" != */* ]] || etxe_die "invalid hidden app-grid launcher ID: $launcher_id"

    cat >"$ETXE_MOUNT/usr/local/share/applications/$launcher_id" <<EOF
[Desktop Entry]
Type=Application
Name=$launcher_id
NoDisplay=true
Hidden=true
EOF
  done
}

etxe_hide_gnome_app_grid_launchers
