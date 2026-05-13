#!/bin/bash

# Make the installer stop early on errors instead of continuing in a broken state
set -eEo pipefail

export ETXE_PATH="${ETXE_PATH:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)}"
export ETXE_INSTALL="$ETXE_PATH/install"
export ETXE_INSTALL_LOG_FILE="${ETXE_INSTALL_LOG_FILE:-/var/log/etxe-install.log}"

source "$ETXE_INSTALL/helpers/all.sh"
source "$ETXE_INSTALL/preflight/all.sh"
source "$ETXE_INSTALL/storage/all.sh"
source "$ETXE_INSTALL/packaging/all.sh"
source "$ETXE_INSTALL/config/all.sh"
source "$ETXE_INSTALL/gnome/all.sh"
source "$ETXE_INSTALL/login/all.sh"
source "$ETXE_INSTALL/post-install/all.sh"
