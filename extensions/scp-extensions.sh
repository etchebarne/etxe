#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
remote_extension_root=".local/share/gnome-shell/extensions"

extension_uuids=()
extension_dirs=()
staging_root=""
staged_extension_dirs=()

cleanup() {
  [[ -z "$staging_root" ]] || rm -rf "$staging_root"
}

trap cleanup EXIT

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

parse_remote() {
  local value="$1"

  vm_user="${value%%@*}"
  vm_host="${value#*@}"

  if [[ "$vm_host" =~ ^(.+):([0-9]+)$ ]]; then
    vm_host="${BASH_REMATCH[1]}"
    vm_port="${BASH_REMATCH[2]}"
  fi
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

extension_gettext_domain() {
  local metadata="$1"
  local line

  while IFS= read -r line; do
    if [[ "$line" =~ \"gettext-domain\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
      printf '%s\n' "${BASH_REMATCH[1]}"
      return 0
    fi
  done <"$metadata"
}

compile_extension_translations() {
  local extension_dir="$1"
  local linguas="$extension_dir/po/LINGUAS"
  local domain lang output_dir

  [[ -f "$linguas" ]] || return 0

  command -v msgfmt >/dev/null || {
    printf 'msgfmt is required to compile extension translations. Install gettext.\n' >&2
    exit 1
  }

  domain="$(extension_gettext_domain "$extension_dir/metadata.json")"
  [[ -n "$domain" && "$domain" != */* && "$domain" != *..* ]] || {
    printf 'Invalid gettext domain for %s\n' "${extension_dir##*/}" >&2
    exit 1
  }

  rm -rf "$extension_dir/locale"

  while IFS= read -r lang; do
    [[ -n "$lang" && "$lang" != \#* ]] || continue
    [[ "$lang" != */* && "$lang" != *..* ]] || {
      printf 'Invalid locale %s for %s\n' "$lang" "${extension_dir##*/}" >&2
      exit 1
    }
    [[ -f "$extension_dir/po/$lang.po" ]] || {
      printf 'Missing %s translation for %s\n' "$lang" "${extension_dir##*/}" >&2
      exit 1
    }

    output_dir="$extension_dir/locale/$lang/LC_MESSAGES"
    mkdir -p "$output_dir"
    msgfmt -c -o "$output_dir/$domain.mo" "$extension_dir/po/$lang.po"
  done <"$linguas"
}

stage_extensions() {
  local index extension_uuid extension_dir staged_dir

  staging_root="$(mktemp -d)"

  for index in "${!extension_uuids[@]}"; do
    extension_uuid="${extension_uuids[$index]}"
    extension_dir="${extension_dirs[$index]}"
    cp -a "$extension_dir" "$staging_root/"
    staged_dir="$staging_root/$extension_uuid"
    compile_extension_translations "$staged_dir"
    staged_extension_dirs+=("$staged_dir")
  done
}

ssh_host_key_options() {
  case "$vm_host" in
    localhost|127.*)
      printf '%s\n' \
        '-o' 'StrictHostKeyChecking=no' \
        '-o' 'UserKnownHostsFile=/dev/null' \
        '-o' 'GlobalKnownHostsFile=/dev/null' \
        '-o' 'LogLevel=ERROR'
      ;;
  esac
}

printf '\nGNOME extension VM copy wizard\n'
printf '================================\n\n'
printf 'This will copy and enable these extensions in your VM:\n'
print_extensions

printf '\nPreparing extension bundles\n'
stage_extensions

cat <<'EOF'

Step 1: In the VM, open Terminal and run exactly this:

  sudo pacman -S --needed openssh iproute2
  sudo systemctl enable --now sshd
  whoami
  ip -4 -br addr

Copy the username printed by whoami.
Copy the VM IPv4 address from the non-lo line, without the /24 suffix.

If the address is 10.0.2.15, the VM is using QEMU user-mode NAT.
That guest address is not reachable directly from the host. For VMs created
with ./iso/create-vm.sh --3d, use the host SSH endpoint printed by that script
instead, normally:

  Host: 127.0.0.1
  Port: 2222

Example:
  enp1s0 UP 192.168.122.91/24

Paste only:
  192.168.122.91

EOF

read -r -p 'Press Enter once the VM commands are done...'

vm_port=""

if [[ $# -gt 0 && "$1" == *@* ]]; then
  parse_remote "$1"
else
  vm_user="$(prompt 'VM username from whoami: ')"
  vm_host="$(prompt 'VM host/IP address: ')"
fi

if [[ "$vm_host" == 10.0.2.* ]]; then
  printf '\n%s is QEMU user-mode NAT and is not directly reachable from the host.\n' "$vm_host" >&2
  printf 'Using the default localhost SSH forward from create-vm.sh --3d.\n\n' >&2
  vm_host="$(prompt_default 'SSH host [127.0.0.1]: ' '127.0.0.1')"
  default_port="2222"
else
  default_port="22"
fi

if [[ -z "$vm_port" ]]; then
  vm_port="$(prompt_default "SSH port [$default_port]: " "$default_port")"
fi
remote="$vm_user@$vm_host"
mapfile -t host_key_options < <(ssh_host_key_options)

if [[ "${#host_key_options[@]}" -gt 0 ]]; then
  printf '\nUsing ephemeral SSH host-key handling for local VM endpoint %s:%s.\n' "$vm_host" "$vm_port"
fi

ssh_options=(
  -o PubkeyAuthentication=no
  -o PreferredAuthentications=password
  "${host_key_options[@]}"
  -p "$vm_port"
)
scp_options=(
  -o PubkeyAuthentication=no
  -o PreferredAuthentications=password
  "${host_key_options[@]}"
  -P "$vm_port"
)

printf '\nStep 2: Testing SSH connection to %s\n' "$remote"
printf 'When prompted, type the VM user password.\n\n'
ssh "${ssh_options[@]}" "$remote" 'printf "Connected as %s on %s\n" "$(whoami)" "$(uname -n 2>/dev/null || printf unknown)"'

printf '\nStep 3: Copying extensions\n\n'
ssh "${ssh_options[@]}" "$remote" "mkdir -p '$remote_extension_root'"

for index in "${!extension_uuids[@]}"; do
  extension_uuid="${extension_uuids[$index]}"
  extension_dir="${staged_extension_dirs[$index]}"

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
