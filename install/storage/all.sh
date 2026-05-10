#!/usr/bin/env bash

etxe_run "$ETXE_INSTALL/storage/partition.sh"
etxe_run "$ETXE_INSTALL/storage/filesystems.sh"
etxe_run "$ETXE_INSTALL/storage/subvolumes.sh"
etxe_run "$ETXE_INSTALL/storage/mounts.sh"
