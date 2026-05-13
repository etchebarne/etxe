# ISO

Archiso build assets live here.

`build.sh` copies Arch's upstream `releng` profile, overlays `profile/airootfs`, appends `packages/iso.pkglist` to the live ISO package list, bundles this repository at `/opt/etxe`, downloads packages for a local pacman repository from `packages/native.pkglist`, enables the graphical installer service, and runs `mkarchiso`.

Build:

```sh
sudo ./iso/build.sh
```

Output ISOs are written to `iso/out/`.

The build machine needs internet access because native packages, dependencies, and fonts are downloaded for each build.

Create a stopped libvirt VM from the newest ISO in `iso/out/`:

```sh
./iso/create-vm.sh
```

This requires libvirt, `virsh`, and UEFI firmware such as `edk2-ovmf`. The VM is defined but not started. It boots in UEFI mode with a 15 GiB disk, 4096 MiB RAM, and 2 vCPUs. It defaults to `qemu:///system`, the `default` storage pool, and the `default` network. With `LIBVIRT_URI=qemu:///session`, it defaults to a file-backed disk in `$XDG_DATA_HOME/etxe/vms/` or `$HOME/.local/share/etxe/vms/` and user-mode networking so a session storage pool or network is not required. Override settings with environment variables, for example:

```sh
VM_NAME=etxe-test LIBVIRT_URI=qemu:///session ./iso/create-vm.sh
```

The script prints the exact start command after creating the VM. If you set `VM_NAME=etxe-test`, start it with:

```sh
virsh --connect qemu:///system start etxe-test
```

For GNOME animation testing, use the 3D profile:

```sh
./iso/create-vm.sh --3d
```

This keeps the normal generated VM name, uses `qemu:///session`, enables virtio 3D acceleration, and uses `egl-headless` for the GL backend with normal SPICE for the console. Set `VM_RENDER_NODE=/dev/dri/renderD128` if the host has multiple render nodes. The script prints the exact `virsh` and `virt-manager` commands to start and open the VM.

If QEMU reports `eglInitialize failed` or `render node init failed`, recreate the VM without 3D acceleration or use a different render node. This is especially relevant on hosts using the proprietary NVIDIA driver because its EGL stack may need `/dev/nvidia*` devices in addition to the DRM render node.

When using `qemu:///session`, open the user-session connection in virt-manager instead of the default system connection:

```sh
virt-manager --connect qemu:///session --show-domain-console VM_NAME
```

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
