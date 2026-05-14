# Etxe Desktop

This extension is an Etxe fork of Desktop Icons NG (DING), imported from the Arch `gnome-shell-extension-desktop-icons-ng` package.

Etxe adds a Shell-side native `PopupMenu` bridge for desktop context menus. The GTK desktop process requests those menus over DBus, and selected menu items route back to the desktop process through application actions. The original GTK context-menu fallback has been removed so desktop menus stay visually consistent with GNOME Shell.

For development installs copied directly into `~/.local/share/gnome-shell/extensions/`, compile schemas after copying:

```sh
glib-compile-schemas "$HOME/.local/share/gnome-shell/extensions/etxe-desktop@etxe.local/schemas"
```

Upstream: <https://gitlab.com/rastersoft/desktop-icons-ng>

License: GPL-3.0-only. See `COPYING`.
