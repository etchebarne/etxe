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
