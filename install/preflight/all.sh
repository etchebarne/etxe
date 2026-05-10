#!/usr/bin/env bash

etxe_run "$ETXE_INSTALL/preflight/environment.sh"
etxe_run "$ETXE_INSTALL/preflight/manifests.sh"
etxe_run "$ETXE_INSTALL/preflight/boot-mode.sh"
etxe_run "$ETXE_INSTALL/preflight/offline-repo.sh"
etxe_run "$ETXE_INSTALL/preflight/commands.sh"
