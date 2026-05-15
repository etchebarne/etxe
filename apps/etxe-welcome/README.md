# Etxe Welcome

Small GNOME welcome guide for installed Etxe systems.

The app is written with GJS, GTK4, and libadwaita so it looks native in the Etxe GNOME session without adding a heavy runtime. It can be opened manually from the app grid, and the systemd user service launches it once on the first graphical login.

First-run state is stored at:

```sh
~/.local/state/etxe/welcome-seen
```
