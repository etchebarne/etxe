# Etxe

Etxe aims to be a friendly Arch Linux configuration for non-technical users. The goal of this project is to make Linux actually approachable for everyone, going the extra mile to make a solid operating system with as little compatibility issues as possible.

## ISO

Build a test ISO with:

```sh
sudo ./iso/build.sh
```

By default, the ISO bundles both the native package repository and the Flatpak system apps listed in `packages/flatpak.pkglist`. For a smaller development ISO without those offline assets, use:

```sh
sudo SKIP_OFFLINE_REPO=YES ./iso/build.sh
```

## Updates

Update an already installed Etxe system from a current checkout with:

```sh
sudo ./update.sh
```

The updater only runs on systems branded as Etxe unless `ETXE_UPDATE_FORCE=YES` is set. It updates native packages, Flatpak apps, Etxe GNOME extensions, GNOME defaults, branding, and systemd-boot when present. It logs to `/var/log/etxe-update.log`, copies the current update payload to `/opt/etxe`, and installs `/usr/local/bin/etxe-update` for future runs. New installs also receive that updater command during installation.

For a VM reachable over SSH, copy the current checkout and run the updater with:

```sh
./iso/update-vm.sh user@127.0.0.1 2222
```

Use the username, host, and port for your VM. VMs created with `./iso/create-vm.sh --3d` normally use host `127.0.0.1` and port `2222`. SSH must be enabled in the VM first with `sudo pacman -S --needed openssh && sudo systemctl enable --now sshd`.
