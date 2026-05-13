#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
remote_extension_root=".local/share/gnome-shell/extensions"

extension_uuids=()
extension_dirs=()

for extension_dir in "$script_dir"/*; do
  [[ -d "$extension_dir" ]] || continue
  [[ -f "$extension_dir/metadata.json" && -f "$extension_dir/extension.js" ]] || continue

  extension_uuid="${extension_dir##*/}"
  extension_uuids+=("$extension_uuid")
  extension_dirs+=("$extension_dir")
done

if [[ "${#extension_uuids[@]}" -eq 0 ]]; then
  printf 'No GNOME Shell extensions found in %s\n' "$script_dir" >&2
  printf 'Expected directories containing metadata.json and extension.js.\n' >&2
  exit 1
fi

print_extensions() {
  local extension_uuid

  for extension_uuid in "${extension_uuids[@]}"; do
    printf '  - %s\n' "$extension_uuid"
  done
}

prompt() {
  local label="$1"
  local value

  while true; do
    read -r -p "$label" value
    if [[ -n "$value" ]]; then
      printf '%s' "$value"
      return 0
    fi
  done
}

prompt_default() {
  local label="$1"
  local default_value="$2"
  local value

  read -r -p "$label" value
  printf '%s' "${value:-$default_value}"
}

shell_join() {
  local joined=""
  local value

  for value in "$@"; do
    joined+=" "
    joined+="$(printf '%q' "$value")"
  done

  printf '%s' "$joined"
}

printf '\nGNOME extension VM copy wizard\n'
printf '================================\n\n'
printf 'This will copy and enable these extensions in your VM:\n'
print_extensions

cat <<'EOF'

Step 1: In the VM, open Terminal and run exactly this:

  sudo pacman -S --needed openssh iproute2
  sudo systemctl enable --now sshd
  whoami
  ip -4 -br addr

Copy the username printed by whoami.
Copy the VM IPv4 address from the non-lo line, without the /24 suffix.

Example:
  enp1s0 UP 192.168.122.91/24

Paste only:
  192.168.122.91

EOF

read -r -p 'Press Enter once the VM commands are done...'

if [[ $# -gt 0 && "$1" == *@* ]]; then
  vm_user="${1%%@*}"
  vm_host="${1#*@}"
else
  vm_user="$(prompt 'VM username from whoami: ')"
  vm_host="$(prompt 'VM IPv4 address: ')"
fi

vm_port="$(prompt_default 'SSH port [22]: ' '22')"
remote="$vm_user@$vm_host"

ssh_options=(
  -o PubkeyAuthentication=no
  -o PreferredAuthentications=password
  -p "$vm_port"
)
scp_options=(
  -o PubkeyAuthentication=no
  -o PreferredAuthentications=password
  -P "$vm_port"
)

printf '\nStep 2: Testing SSH connection to %s\n' "$remote"
printf 'When prompted, type the VM user password.\n\n'
ssh "${ssh_options[@]}" "$remote" 'printf "Connected as %s on %s\n" "$(whoami)" "$(uname -n 2>/dev/null || printf unknown)"'

printf '\nStep 3: Copying extensions\n\n'
ssh "${ssh_options[@]}" "$remote" "mkdir -p '$remote_extension_root'"

for index in "${!extension_uuids[@]}"; do
  extension_uuid="${extension_uuids[$index]}"
  extension_dir="${extension_dirs[$index]}"

  printf 'Copying %s\n' "$extension_uuid"
  ssh "${ssh_options[@]}" "$remote" "rm -rf '$remote_extension_root/$extension_uuid'"
  scp "${scp_options[@]}" -r "$extension_dir" "$remote:$remote_extension_root/"
done

printf '\nStep 4: Enabling extensions\n\n'
remote_args="$(shell_join "${extension_uuids[@]}")"

read -r -d '' remote_enable_script <<'REMOTE' || true
set -e

current="$(dbus-run-session -- gsettings get org.gnome.shell enabled-extensions 2>/dev/null || printf '[]')"

for uuid in "$@"; do
  case "$current" in
    *"'$uuid'"*)
      ;;
    '@as []'|'[]')
      current="['$uuid']"
      ;;
    *)
      current="${current%]}"
      current="$current, '$uuid']"
      ;;
  esac
done

dbus-run-session -- gsettings set org.gnome.shell disable-user-extensions false
dbus-run-session -- gsettings set org.gnome.shell enabled-extensions "$current"

printf 'Enabled extensions are now: %s\n' "$current"
REMOTE

ssh "${ssh_options[@]}" "$remote" "bash -s --$remote_args" <<<"$remote_enable_script"

cat <<EOF

Done.

In the VM, log out of GNOME and log back in so GNOME Shell loads newly copied extension code.

To verify inside the VM, run:

  gnome-extensions list --enabled
  gnome-extensions info ${extension_uuids[0]}

EOF
