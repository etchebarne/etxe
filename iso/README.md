# ISO

Archiso build assets live here.

`build.sh` copies Arch's upstream `releng` profile, overlays `profile/airootfs`, appends `packages/iso.pkglist` to the live ISO package list, bundles this repository at `/opt/etxe`, downloads packages for a local pacman repository from `packages/native.pkglist`, enables the graphical installer service, and runs `mkarchiso`.

Build:

```sh
sudo ./iso/build.sh
```

Output ISOs are written to `iso/out/`.

The build machine needs internet access because native packages, dependencies, and fonts are downloaded for each build.

Smaller GUI development ISO:

```sh
sudo SKIP_OFFLINE_REPO=YES ./iso/build.sh
```

This skips bundling the offline install repository. The GUI still works, but clicking install will require internet because native packages are not embedded.

For VM testing, boot the ISO in UEFI mode with a blank virtual disk of at least 15 GiB.

If the service fails, inspect the live ISO logs with:

```sh
journalctl -u etxe-installer-gui.service -b --no-pager
journalctl -u etxe-install.service -b --no-pager
less /var/log/etxe-install.log
```
