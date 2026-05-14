#!/usr/bin/env bash

set -euo pipefail

repo_path="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
remote="${1:-}"
port="${2:-${VM_SSH_PORT:-22}}"
target_path="${ETXE_VM_UPDATE_PATH:-/tmp/etxe}"

usage() {
  printf 'Usage: %s user@host [port]\n' "${0##*/}" >&2
  printf 'Example: %s martin@127.0.0.1 2222\n' "${0##*/}" >&2
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

log() {
  printf '==> %s\n' "$*"
}

shell_quote() {
  printf '%q' "$1"
}

ssh_host_key_options() {
  local host="$1"

  case "$host" in
    localhost|127.*)
      printf '%s\n' \
        '-o' 'StrictHostKeyChecking=no' \
        '-o' 'UserKnownHostsFile=/dev/null' \
        '-o' 'GlobalKnownHostsFile=/dev/null' \
        '-o' 'LogLevel=ERROR'
      ;;
  esac
}

[[ -n "$remote" ]] || {
  usage
  exit 1
}

[[ "$remote" == *@* ]] || die "remote must look like user@host"
[[ "$port" =~ ^[0-9]+$ ]] || die "port must be a TCP port number"
(( port >= 1 && port <= 65535 )) || die "port must be between 1 and 65535"
[[ -n "$target_path" && "$target_path" != "/" ]] || die "ETXE_VM_UPDATE_PATH cannot be empty or /"

remote_host="${remote#*@}"
target_path_quoted="$(shell_quote "$target_path")"
mapfile -t host_key_options < <(ssh_host_key_options "$remote_host")

ssh_options=(
  -o PubkeyAuthentication=no
  -o PreferredAuthentications=password
  "${host_key_options[@]}"
  -p "$port"
)

log "Preparing $remote:$target_path"
ssh "${ssh_options[@]}" "$remote" "rm -rf $target_path_quoted && mkdir -p $target_path_quoted"

log "Copying Etxe repository"
tar \
  --exclude='./.git' \
  --exclude='./iso/cache' \
  --exclude='./iso/out' \
  --exclude='./iso/.work' \
  --exclude='./*.iso' \
  --exclude='./repo' \
  --exclude='./flatpak-system.tar' \
  -C "$repo_path" \
  -cf - . | ssh "${ssh_options[@]}" "$remote" "tar -C $target_path_quoted -xf -"

log "Running update in VM"
ssh -t "${ssh_options[@]}" "$remote" "cd $target_path_quoted && sudo ./update.sh"
