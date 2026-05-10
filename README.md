# etxe

Etxe is an Arch-compatible Linux configuration monorepo for a KDE Plasma desktop.

## Stack

- Desktop: KDE Plasma
- Display manager: SDDM
- Audio: PipeWire with `pipewire-pulse`
- Root filesystem: Btrfs with zstd compression
- Boot: systemd-boot
- Networking: NetworkManager with systemd-resolved
- Apps: native Arch packages plus Flatpak
- Install mode: offline-capable for native packages

## Structure

```text
install.sh                 Minimal install entry point
install/helpers/           Shared shell helpers and defaults
install/preflight/         Root, disk, UEFI, and dependency checks
install/storage/           Partitioning, formatting, Btrfs subvolumes, mounts
install/packaging/         Native package installation and fstab generation
install/config/            Base system, boot, networking, audio, Flatpak setup
install/login/             User creation and SDDM enablement
install/post-install/      Final helpers and operator instructions
gui/                       Qt/PySide live ISO installer UI
packages/native.pkglist    Pacman package manifest
packages/flatpak.pkglist   Flatpak application manifest
packages/iso.pkglist       Live ISO package manifest
iso/                       Archiso overlay and ISO build wrapper
```

`install.sh` intentionally stays tidy. Each phase lives in `install/<phase>/all.sh`; those entry points source smaller ordered scripts for each concern, similar to Omarchy's entry point style.

## Disk Layout

The installer uses a single disk with GPT:

- EFI system partition: 1 GiB, FAT32, mounted at `/boot`
- Root partition: remaining space, Btrfs, mounted at `/`

Btrfs subvolumes:

- `@` mounted at `/`
- `@home` mounted at `/home`
- `@var_log` mounted at `/var/log`
- `@snapshots` mounted at `/.snapshots`

Btrfs mount options:

```text
noatime,compress=zstd:3,ssd,space_cache=v2,discard=async
```

## Installer

`install.sh` is the backend installer, not a user-facing CLI. The live ISO starts the graphical installer in `gui/` first. The GUI collects install choices, writes `/etc/etxe/install.env`, starts `etxe-install.service`, and shows friendly progress while technical logs remain optional.

The script partitions and formats `DISK`, installs the base system, enables systemd-boot, SDDM, NetworkManager, systemd-resolved, PipeWire, and Flatpak support.

Review `packages/native.pkglist` and `packages/flatpak.pkglist` before installing.

## ISO

Build a test ISO with:

```sh
sudo ./iso/build.sh
```

The build caches downloaded packages and Red Hat Display fonts under `iso/cache/`, so later builds can reuse them. For a smaller GUI development ISO without the bundled offline package repository, use:

```sh
sudo SKIP_OFFLINE_REPO=YES ./iso/build.sh
```

The ISO bundles this repository at `/opt/etxe`, includes a local pacman repository for `packages/native.pkglist`, and launches the graphical installer automatically. Boot the VM in UEFI mode with a blank virtual disk of at least 30 GiB.

The build machine needs internet access to create the ISO. The installed system's native packages do not need internet during installation. Flatpak apps from `packages/flatpak.pkglist` are installed automatically from Flathub when internet is available; failures do not abort the base OS install.

The graphical installer currently supports disk selection, user/password, hostname, full live-system locale list, full keyboard layout list, full timezone list, optional Wi-Fi connection, review, progress, and success/failure actions.

If the auto-installer fails in the live ISO, check:

```sh
journalctl -u etxe-installer-gui.service -b --no-pager
journalctl -u etxe-install.service -b --no-pager
less /var/log/etxe-install.log
```
