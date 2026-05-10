#!/usr/bin/env bash

etxe_configure_boot() {
  local root_part root_partuuid
  root_part="$(etxe_part_path "$DISK" 2)"
  root_partuuid="$(blkid -s PARTUUID -o value "$root_part")"
  [[ -n "$root_partuuid" ]] || etxe_die "failed to read PARTUUID for $root_part"

  etxe_log "Installing systemd-boot"
  arch-chroot "$ETXE_MOUNT" bootctl install

  mkdir -p "$ETXE_MOUNT/boot/loader/entries"
  cat >"$ETXE_MOUNT/boot/loader/loader.conf" <<'EOF'
default arch.conf
timeout 3
console-mode max
editor no
EOF

  cat >"$ETXE_MOUNT/boot/loader/entries/arch.conf" <<EOF
title Etxe
linux /vmlinuz-linux
initrd /intel-ucode.img
initrd /amd-ucode.img
initrd /initramfs-linux.img
options root=PARTUUID=$root_partuuid rw rootflags=subvol=@
EOF
}

etxe_configure_boot
