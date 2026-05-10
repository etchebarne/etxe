# iso

Archiso build assets live here.

`build.sh` copies Arch's upstream `releng` profile, overlays `profile/airootfs`, appends `packages/iso.pkglist` to the live ISO package list, bundles this repository at `/opt/etxe`, builds a local pacman repository from `packages/native.pkglist`, enables the graphical installer service, and runs `mkarchiso`.

The build also downloads Red Hat Display TTF files into the live ISO so the installer matches the intended visual design.

Build:

```sh
sudo ./iso/build.sh
```

Output ISOs are written to `iso/out/`.

The build machine needs internet access the first time because native packages, dependencies, and Red Hat Display fonts are downloaded into `iso/cache/`.

The package cache is reused automatically between builds.

Smaller GUI development ISO:

```sh
sudo SKIP_OFFLINE_REPO=YES ./iso/build.sh
```

This skips bundling the offline install repository. The GUI still works, but clicking install will require internet because native packages are not embedded.

Useful cache controls:

```sh
sudo REFRESH_FONT_CACHE=YES ./iso/build.sh
sudo CACHE_PATH=/path/to/cache ./iso/build.sh
```

The live ISO starts `etxe-installer-gui.service`, which launches a Qt/PySide installer on `tty1`. The GUI writes `/etc/etxe/install.env`, starts `etxe-install.service`, and follows `/var/log/etxe-install.log` for progress. The install does not require internet for native packages because `pacstrap` uses `/opt/etxe/repo/os/x86_64` when present. Flatpak apps from `packages/flatpak.pkglist` are installed automatically from Flathub when internet is available; failures do not abort the base OS install.

The GUI currently supports disk selection, user/password, hostname, locale, keyboard layout, timezone, optional Wi-Fi connection, review, progress, and success/failure actions.

For VM testing, boot the ISO in UEFI mode with a blank virtual disk of at least 30 GiB. The auto runner selects the first non-removable disk unless `DISK` is set in the environment or `etxe.disk=/dev/...` is passed on the kernel command line.

If the service fails, inspect the live ISO logs with:

```sh
journalctl -u etxe-installer-gui.service -b --no-pager
journalctl -u etxe-install.service -b --no-pager
less /var/log/etxe-install.log
```
