#!/usr/bin/env bash

etxe_preflight_boot_mode() {
  [[ -d /sys/firmware/efi/efivars ]] || etxe_die "boot the VM in UEFI mode"
}

etxe_preflight_boot_mode
