#!/usr/bin/env bash

etxe_run "$ETXE_INSTALL/post-install/flatpaks.sh"
etxe_run "$ETXE_INSTALL/post-install/updater.sh"
etxe_run "$ETXE_INSTALL/post-install/finish.sh"
