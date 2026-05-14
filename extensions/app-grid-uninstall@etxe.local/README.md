# App Grid Uninstall

Adds an `Uninstall...` action to GNOME app-grid right-click menus.

The Etxe installer installs and enables every GNOME Shell extension in `extensions/` by default.

The extension currently supports:

- Flatpak apps detected from GNOME launcher IDs and Flatpak export paths.
- Arch packages detected with `pacman -Qo` from the app's `.desktop` file.
- AUR and other foreign packages, because installed AUR packages are still registered in pacman's local database. The dialog labels these as `AUR/foreign` when `pacman -Qm` matches.

Pacman removals use `pkexec pacman -Rns --noconfirm <package>` after the GNOME confirmation dialog. Before confirming, the extension tries to preview the packages pacman plans to remove with `pacman -Rns --print --print-format %n <package>`.

## Install For Development

```sh
uuid="app-grid-uninstall@etxe.local"
dest="$HOME/.local/share/gnome-shell/extensions/$uuid"
mkdir -p "$dest"
cp -r "extensions/$uuid"/* "$dest/"
while IFS= read -r lang; do
  [ -n "$lang" ] || continue
  mkdir -p "$dest/locale/$lang/LC_MESSAGES"
  msgfmt -c -o "$dest/locale/$lang/LC_MESSAGES/app-grid-uninstall.mo" "$dest/po/$lang.po"
done < "$dest/po/LINGUAS"
gnome-extensions enable "$uuid"
```

On Wayland, log out and back in if GNOME does not pick up the extension immediately.

## Safety Notes

- Critical desktop and package-manager packages are blocked in `extension.js`.
- Pacman uses `-Rns`, not `-Rc`, so it removes only dependencies that are no longer required by other packages.
- The extension does not call `yay` or `paru`; pacman can remove installed AUR packages directly.
