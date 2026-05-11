#!/usr/bin/env bash

etxe_run "$ETXE_INSTALL/config/base.sh"
etxe_run "$ETXE_INSTALL/config/branding.sh"
etxe_run "$ETXE_INSTALL/config/gnome.sh"
etxe_run "$ETXE_INSTALL/config/boot.sh"
etxe_run "$ETXE_INSTALL/config/networking.sh"
etxe_run "$ETXE_INSTALL/config/audio.sh"
etxe_run "$ETXE_INSTALL/config/flatpak.sh"
