# gui

Qt/PySide live ISO installer UI.

The GUI is a front-end only. It collects install choices, writes `/etc/etxe/install.env`, starts `etxe-install.service`, and follows `/var/log/etxe-install.log` for progress.

The shell installer under `install/` remains the installation backend.
