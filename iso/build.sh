#!/bin/bash

set -eEo pipefail

REPO_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
ISO_PATH="$REPO_PATH/iso"
ARCHISO_PROFILE="${ARCHISO_PROFILE:-/usr/share/archiso/configs/releng}"
WORK_PATH="${WORK_PATH:-/var/tmp/etxe-iso-work}"
OUT_PATH="${OUT_PATH:-$ISO_PATH/out}"
PROFILE_PATH="$WORK_PATH/profile"
TARGET_REPO_PATH="$PROFILE_PATH/airootfs/opt/etxe"
OFFLINE_REPO_PATH="$TARGET_REPO_PATH/repo/os/x86_64"
PACKAGE_REPO_PATH="$WORK_PATH/offline-repo/os/x86_64"
PACMAN_DB_PATH="$WORK_PATH/pacman-db"
FONT_PATH="$PROFILE_PATH/airootfs/usr/share/fonts/TTF"
RED_HAT_DISPLAY_URL="https://raw.githubusercontent.com/RedHatOfficial/RedHatFont/master/fonts/Proportional/RedHatDisplay/ttf"
SKIP_OFFLINE_REPO="${SKIP_OFFLINE_REPO:-NO}"

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

log() {
  printf '==> %s\n' "$*"
}

download_red_hat_display() {
  local font_weight target_font

  command -v curl >/dev/null || die "curl is required to download Red Hat Display"
  mkdir -p "$FONT_PATH"

  for font_weight in Regular Medium SemiBold Bold; do
    target_font="$FONT_PATH/RedHatDisplay-$font_weight.ttf"

    log "Downloading Red Hat Display $font_weight"
    curl \
      --fail \
      --location \
      --retry 3 \
      --output "$target_font" \
      "$RED_HAT_DISPLAY_URL/RedHatDisplay-$font_weight.ttf"
  done
}

bundle_repo() {
  mkdir -p "$TARGET_REPO_PATH"
  tar \
    --exclude='./.git' \
    --exclude='./iso/cache' \
    --exclude='./iso/out' \
    --exclude='./iso/.work' \
    --exclude='./*.iso' \
    -C "$REPO_PATH" \
    -cf - . | tar -C "$TARGET_REPO_PATH" -xf -
}

set_env_value() {
  local file key value temp_file
  file="$1"
  key="$2"
  value="$3"
  temp_file="$(mktemp)"

  if [[ -f "$file" ]] && grep -q "^$key=" "$file"; then
    while IFS= read -r line; do
      if [[ "$line" == "$key="* ]]; then
        printf '%s=%s\n' "$key" "$value"
      else
        printf '%s\n' "$line"
      fi
    done <"$file" >"$temp_file"
  else
    [[ -f "$file" ]] && cp "$file" "$temp_file"
    printf '%s=%s\n' "$key" "$value" >>"$temp_file"
  fi

  install -D -m 0644 "$temp_file" "$file"
  rm -f "$temp_file"
}

set_shell_value() {
  local file key value temp_file escaped_value replaced
  file="$1"
  key="$2"
  value="$3"
  temp_file="$(mktemp)"
  escaped_value="${value//\\/\\\\}"
  escaped_value="${escaped_value//\"/\\\"}"
  replaced=NO

  if [[ -f "$file" ]]; then
    while IFS= read -r line; do
      if [[ "$line" == "$key="* ]]; then
        printf '%s="%s"\n' "$key" "$escaped_value"
        replaced=YES
      else
        printf '%s\n' "$line"
      fi
    done <"$file" >"$temp_file"
  fi

  if [[ "$replaced" == "NO" ]]; then
    printf '%s="%s"\n' "$key" "$escaped_value" >>"$temp_file"
  fi

  install -D -m 0644 "$temp_file" "$file"
  rm -f "$temp_file"
}

brand_iso_profile() {
  local boot_config profiledef
  profiledef="$PROFILE_PATH/profiledef.sh"

  [[ -f "$profiledef" ]] || die "missing archiso profile definition: $profiledef"

  set_shell_value "$profiledef" iso_name etxe
  set_shell_value "$profiledef" iso_label "ETXE_$(date +%Y%m)"
  set_shell_value "$profiledef" iso_publisher Etxe
  set_shell_value "$profiledef" iso_application "Etxe Live Installer"

  for boot_config in \
    "$PROFILE_PATH"/efiboot/loader/entries/*.conf \
    "$PROFILE_PATH"/grub/*.cfg \
    "$PROFILE_PATH"/syslinux/*.cfg; do
    [[ -f "$boot_config" ]] || continue
    sed -i 's/Arch Linux install medium/Etxe installer/g' "$boot_config"
  done
}

sync_offline_repo() {
  local -a install_packages package_files
  local pacman_config

  if [[ "$SKIP_OFFLINE_REPO" == "YES" ]]; then
    log "Skipping bundled offline package repository"
    set_env_value "$PROFILE_PATH/airootfs/etc/etxe/install.env" ETXE_REQUIRE_OFFLINE_REPO NO
    return 0
  fi

  mapfile -t install_packages < <(grep -Ev '^[[:space:]]*(#|$)' "$REPO_PATH/packages/native.pkglist")
  [[ "${#install_packages[@]}" -gt 0 ]] || die "no native packages configured"

  mkdir -p "$PACKAGE_REPO_PATH" "$PACMAN_DB_PATH"

  log "Downloading offline package repository"
  pacman_config="$WORK_PATH/pacman.conf"
  cp /etc/pacman.conf "$pacman_config"
  sed -i 's/^DownloadUser/#&/' "$pacman_config"
  rm -f "$PACMAN_DB_PATH"/sync/*.part

  pacman \
    -Syw \
    --noconfirm \
    --config "$pacman_config" \
    --disable-sandbox \
    --dbpath "$PACMAN_DB_PATH" \
    --cachedir "$PACKAGE_REPO_PATH" \
    "${install_packages[@]}"

  shopt -s nullglob
  package_files=("$PACKAGE_REPO_PATH"/*.pkg.tar.zst "$PACKAGE_REPO_PATH"/*.pkg.tar.xz)
  [[ "${#package_files[@]}" -gt 0 ]] || die "offline package repository has no packages"
  rm -f "$PACKAGE_REPO_PATH"/etxe.db "$PACKAGE_REPO_PATH"/etxe.db.tar.* "$PACKAGE_REPO_PATH"/etxe.files "$PACKAGE_REPO_PATH"/etxe.files.tar.*
  repo-add "$PACKAGE_REPO_PATH/etxe.db.tar.zst" "${package_files[@]}"
  shopt -u nullglob

  log "Bundling offline package repository"
  mkdir -p "$OFFLINE_REPO_PATH"
  cp -a "$PACKAGE_REPO_PATH/." "$OFFLINE_REPO_PATH/"
}

[[ "${EUID:-$(id -u)}" -eq 0 ]] || die "run as root"
[[ -d "$ARCHISO_PROFILE" ]] || die "missing archiso releng profile: $ARCHISO_PROFILE"
command -v mkarchiso >/dev/null || die "mkarchiso is required"
command -v pacman >/dev/null || die "pacman is required"
command -v repo-add >/dev/null || die "repo-add is required"
command -v tar >/dev/null || die "tar is required"

rm -rf "$WORK_PATH"
mkdir -p "$WORK_PATH" "$OUT_PATH"

cp -a "$ARCHISO_PROFILE" "$PROFILE_PATH"
brand_iso_profile
cp -a "$ISO_PATH/profile/airootfs/." "$PROFILE_PATH/airootfs/"

download_red_hat_display
bundle_repo
sync_offline_repo

cat "$REPO_PATH/packages/iso.pkglist" >>"$PROFILE_PATH/packages.x86_64"
sort -u "$PROFILE_PATH/packages.x86_64" -o "$PROFILE_PATH/packages.x86_64"

chmod +x "$TARGET_REPO_PATH/install.sh"
chmod +x "$PROFILE_PATH/airootfs/usr/local/bin/etxe-install-auto"
chmod +x "$PROFILE_PATH/airootfs/usr/local/bin/etxe-installer-gui"
chmod +x "$PROFILE_PATH/airootfs/usr/local/bin/etxe-installer-session"

mkdir -p "$PROFILE_PATH/airootfs/etc/systemd/system/graphical.target.wants"
ln -sf ../etxe-installer-gui.service "$PROFILE_PATH/airootfs/etc/systemd/system/graphical.target.wants/etxe-installer-gui.service"

mkarchiso -v -w "$WORK_PATH/mkarchiso" -o "$OUT_PATH" "$PROFILE_PATH"
