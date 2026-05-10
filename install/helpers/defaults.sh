#!/usr/bin/env bash

export ETXE_NATIVE_PACKAGES_FILE="${ETXE_NATIVE_PACKAGES_FILE:-$ETXE_PATH/packages/native.pkglist}"
export ETXE_FLATPAK_PACKAGES_FILE="${ETXE_FLATPAK_PACKAGES_FILE:-$ETXE_PATH/packages/flatpak.pkglist}"
export ETXE_OFFLINE_REPO="${ETXE_OFFLINE_REPO:-$ETXE_PATH/repo/os/$(uname -m)}"
export ETXE_MOUNT="${ETXE_MOUNT:-/mnt}"
export ETXE_BTRFS_OPTS="${ETXE_BTRFS_OPTS:-noatime,compress=zstd:3,ssd,space_cache=v2,discard=async}"
export ETXE_FINISH_ACTION="${ETXE_FINISH_ACTION:-none}"
