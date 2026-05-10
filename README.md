# Etxe

Etxe aims to be a friendly Arch Linux configuration for non-technical users. The goal of this project is to make Linux actually approachable for everyone, going the extra mile to make a solid operating system with as little compatibility issues as possible.

## ISO

Build a test ISO with:

```sh
sudo ./iso/build.sh
```

For a smaller development ISO without the bundled offline package repository, use:

```sh
sudo SKIP_OFFLINE_REPO=YES ./iso/build.sh
```
