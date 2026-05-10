#!/usr/bin/env bash

etxe_preflight_manifests() {
  [[ -f "$ETXE_NATIVE_PACKAGES_FILE" ]] || etxe_die "missing $ETXE_NATIVE_PACKAGES_FILE"
  [[ -f "$ETXE_FLATPAK_PACKAGES_FILE" ]] || etxe_die "missing $ETXE_FLATPAK_PACKAGES_FILE"
}

etxe_preflight_manifests
