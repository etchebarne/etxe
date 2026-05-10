#!/bin/bash

set -eEo pipefail

REPO_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_PATH="${OUT_PATH:-$REPO_PATH/iso/out}"
LIBVIRT_URI="${LIBVIRT_URI:-qemu:///system}"
VM_NAME="${VM_NAME:-etxe-test-$(date +%Y%m%d-%H%M%S)}"
VM_RAM_MB="${VM_RAM_MB:-4096}"
VM_VCPUS="${VM_VCPUS:-2}"
VM_DISK_GIB="${VM_DISK_GIB:-15}"
VM_DISK_POOL="${VM_DISK_POOL:-default}"
VM_DISK_VOLUME="${VM_DISK_VOLUME:-$VM_NAME.qcow2}"
VM_NETWORK="${VM_NETWORK:-default}"

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

log() {
  printf '==> %s\n' "$*"
}

latest_iso() {
  local iso latest

  shopt -s nullglob
  for iso in "$OUT_PATH"/*.iso; do
    if [[ -z "${latest:-}" || "$iso" -nt "$latest" ]]; then
      latest="$iso"
    fi
  done
  shopt -u nullglob

  [[ -n "${latest:-}" ]] || die "no ISO files found in $OUT_PATH"
  printf '%s\n' "$latest"
}

xml_escape() {
  local value
  value="$1"
  value="${value//&/&amp;}"
  value="${value//</&lt;}"
  value="${value//>/&gt;}"
  value="${value//\"/&quot;}"
  printf '%s' "$value"
}

cleanup_on_error() {
  if [[ "${DISK_VOLUME_CREATED:-NO}" == "YES" ]]; then
    virsh --connect "$LIBVIRT_URI" vol-delete --pool "$VM_DISK_POOL" "$VM_DISK_VOLUME" >/dev/null 2>&1 || true
  fi
}

[[ -d "$OUT_PATH" ]] || die "missing ISO output directory: $OUT_PATH"
command -v virsh >/dev/null || die "virsh is required"
virsh --connect "$LIBVIRT_URI" uri >/dev/null || die "cannot connect to libvirt at $LIBVIRT_URI"

ISO_FILE="$(latest_iso)"
DOMAIN_XML="$(mktemp)"
DISK_VOLUME_CREATED=NO
trap cleanup_on_error ERR
trap 'rm -f "$DOMAIN_XML"' EXIT

if virsh --connect "$LIBVIRT_URI" dominfo "$VM_NAME" >/dev/null 2>&1; then
  die "VM already exists: $VM_NAME"
fi

if virsh --connect "$LIBVIRT_URI" vol-info --pool "$VM_DISK_POOL" "$VM_DISK_VOLUME" >/dev/null 2>&1; then
  die "storage volume already exists in pool $VM_DISK_POOL: $VM_DISK_VOLUME"
fi

log "Using ISO: $ISO_FILE"
log "Creating VM: $VM_NAME"

virsh --connect "$LIBVIRT_URI" vol-create-as \
  --pool "$VM_DISK_POOL" \
  --name "$VM_DISK_VOLUME" \
  --capacity "${VM_DISK_GIB}G" \
  --format qcow2 >/dev/null
DISK_VOLUME_CREATED=YES
DISK_PATH="$(virsh --connect "$LIBVIRT_URI" vol-path --pool "$VM_DISK_POOL" "$VM_DISK_VOLUME")"

cat >"$DOMAIN_XML" <<EOF
<domain type="kvm">
  <name>$(xml_escape "$VM_NAME")</name>
  <memory unit="MiB">$VM_RAM_MB</memory>
  <currentMemory unit="MiB">$VM_RAM_MB</currentMemory>
  <vcpu placement="static">$VM_VCPUS</vcpu>
  <os firmware="efi">
    <type arch="x86_64" machine="q35">hvm</type>
    <boot dev="cdrom"/>
    <boot dev="hd"/>
  </os>
  <features>
    <acpi/>
    <apic/>
  </features>
  <cpu mode="host-passthrough" check="none"/>
  <clock offset="utc"/>
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>restart</on_reboot>
  <on_crash>destroy</on_crash>
  <devices>
    <disk type="file" device="disk">
      <driver name="qemu" type="qcow2"/>
      <source file="$(xml_escape "$DISK_PATH")"/>
      <target dev="vda" bus="virtio"/>
    </disk>
    <disk type="file" device="cdrom">
      <driver name="qemu" type="raw"/>
      <source file="$(xml_escape "$ISO_FILE")"/>
      <target dev="sda" bus="sata"/>
      <readonly/>
    </disk>
    <interface type="network">
      <source network="$(xml_escape "$VM_NETWORK")"/>
      <model type="virtio"/>
    </interface>
    <graphics type="spice" autoport="yes"/>
    <video>
      <model type="virtio"/>
    </video>
    <channel type="spicevmc">
      <target type="virtio" name="com.redhat.spice.0"/>
    </channel>
  </devices>
</domain>
EOF

virsh --connect "$LIBVIRT_URI" define "$DOMAIN_XML" >/dev/null
DISK_VOLUME_CREATED=NO

log "Created $VM_NAME"
log "Start it with: virsh --connect $LIBVIRT_URI start $VM_NAME"
