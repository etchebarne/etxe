# GNOME Extensions

This directory contains Etxe GNOME Shell extensions. Each extension lives in its own directory and can be installed independently while developing.

Directory names must match each extension's GNOME UUID from `metadata.json`. The installer copies every directory containing `metadata.json` and `extension.js` into `/usr/share/gnome-shell/extensions/` and enables each one by default. If an extension has a `schemas/` directory, the installer compiles it after copying.
