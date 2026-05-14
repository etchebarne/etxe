#!/usr/bin/env bash

etxe_archive_repo_to() {
  local target="$1"

  tar \
    --exclude='./.git' \
    --exclude='./iso/cache' \
    --exclude='./iso/out' \
    --exclude='./iso/.work' \
    --exclude='./*.iso' \
    --exclude='./repo' \
    --exclude='./flatpak-system.tar' \
    -C "$ETXE_PATH" \
    -cf - . | tar -C "$target" -xf -
}

etxe_write_update_command() {
  local command_path="$1"
  local system_path="$2"

  install -d -m 0755 "$(dirname -- "$command_path")"
  {
    printf '#!/usr/bin/env bash\n'
    printf 'exec %q/update.sh "$@"\n' "$system_path"
  } >"$command_path"
  chmod 0755 "$command_path"
}
