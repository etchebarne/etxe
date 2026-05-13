#!/bin/bash

set -eEo pipefail

REPO_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_PATH="${OUT_PATH:-$REPO_PATH/iso/out}"
VM_PROFILE=default

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<EOF
Usage: ${0##*/} [--3d]

Options:
  --3d, --gnome-animations  Create a session VM with virtio 3D for GNOME animation testing.
  -h, --help                Show this help.
EOF
}

log() {
  printf '==> %s\n' "$*"
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --3d|3d|--gnome-animations|gnome-animations)
      VM_PROFILE=gnome-animations
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
  shift
done

if [[ "$VM_PROFILE" == "gnome-animations" ]]; then
  : "${LIBVIRT_URI:=qemu:///session}"
  : "${VM_ACCEL_3D:=YES}"
else
  : "${LIBVIRT_URI:=qemu:///system}"
  : "${VM_ACCEL_3D:=NO}"
fi

VM_NAME="${VM_NAME:-etxe-test-$(date +%Y%m%d-%H%M%S)}"
VM_RAM_MB="${VM_RAM_MB:-4096}"
VM_VCPUS="${VM_VCPUS:-2}"
VM_DISK_GIB="${VM_DISK_GIB:-15}"
VM_DISK_POOL_PROVIDED="${VM_DISK_POOL+x}"
VM_DISK_POOL="${VM_DISK_POOL:-default}"
VM_DISK_VOLUME="${VM_DISK_VOLUME:-$VM_NAME.qcow2}"
VM_DISK_DIR="${VM_DISK_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/etxe/vms}"
VM_DISK_PATH="${VM_DISK_PATH:-}"
VM_NETWORK_PROVIDED="${VM_NETWORK+x}"
VM_NETWORK="${VM_NETWORK:-default}"
VM_RENDER_NODE="${VM_RENDER_NODE:-}"

if [[ "$LIBVIRT_URI" == "qemu:///session" ]]; then
  if [[ -z "$VM_DISK_POOL_PROVIDED" && -z "$VM_DISK_PATH" ]]; then
    VM_DISK_POOL=""
    VM_DISK_PATH="$VM_DISK_DIR/$VM_NAME.qcow2"
  fi

  if [[ -z "$VM_NETWORK_PROVIDED" ]]; then
    VM_NETWORK="user"
  fi
fi

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
  if [[ "${DISK_FILE_CREATED:-NO}" == "YES" ]]; then
    rm -f -- "$VM_DISK_PATH" >/dev/null 2>&1 || true
  fi
}

detect_render_node() {
  local node restore_nullglob

  restore_nullglob="$(shopt -p nullglob || true)"
  shopt -s nullglob
  for node in /dev/dri/renderD*; do
    eval "$restore_nullglob"
    printf '%s\n' "$node"
    return 0
  done
  eval "$restore_nullglob"

  return 1
}

render_node_driver() {
  local driver_path node_name

  node_name="${1##*/}"
  driver_path="$(readlink -f "/sys/class/drm/$node_name/device/driver" 2>/dev/null || true)"
  [[ -n "$driver_path" ]] || return 1
  printf '%s\n' "${driver_path##*/}"
}

configure_acceleration() {
  local accel_3d render_driver render_node

  case "$VM_ACCEL_3D" in
    YES|yes|true|TRUE|1)
      accel_3d=YES
      ;;
    NO|no|false|FALSE|0)
      accel_3d=NO
      ;;
    AUTO|auto)
      accel_3d=AUTO
      ;;
    *)
      die "VM_ACCEL_3D must be YES, NO, or AUTO"
      ;;
  esac

  if [[ -n "$VM_RENDER_NODE" ]]; then
    [[ -e "$VM_RENDER_NODE" ]] || die "render node does not exist: $VM_RENDER_NODE"
    render_node="$VM_RENDER_NODE"
  elif [[ "$accel_3d" != "NO" ]]; then
    render_node="$(detect_render_node || true)"
  fi

  if [[ "$accel_3d" == "YES" && -z "${render_node:-}" ]]; then
    die "VM_ACCEL_3D=YES requires a render node such as /dev/dri/renderD128"
  fi

  if [[ "$accel_3d" != "NO" && -n "${render_node:-}" ]]; then
    VM_ACCEL_3D_ENABLED=YES
    VM_RENDER_NODE="$render_node"
    render_driver="$(render_node_driver "$VM_RENDER_NODE" || true)"
    if [[ "$LIBVIRT_URI" == "qemu:///system" && "$render_driver" == "nvidia" ]]; then
      VM_ACCEL_3D_WARNING="proprietary NVIDIA render nodes often fail SPICE OpenGL under qemu:///system; try LIBVIRT_URI=qemu:///session"
    fi
    VM_GRAPHICS_XML="    <graphics type=\"spice\" autoport=\"yes\"/>
    <graphics type=\"egl-headless\">
      <gl enable=\"yes\" rendernode=\"$(xml_escape "$VM_RENDER_NODE")\"/>
    </graphics>"
    VM_VIDEO_MODEL_XML='      <model type="virtio" heads="1" primary="yes">
        <acceleration accel3d="yes"/>
      </model>'
  else
    VM_ACCEL_3D_ENABLED=NO
    VM_GRAPHICS_XML='    <graphics type="spice" autoport="yes"/>'
    VM_VIDEO_MODEL_XML='      <model type="virtio"/>'
  fi
}

configure_network() {
  if [[ "$VM_NETWORK" == "user" ]]; then
    VM_INTERFACE_XML='    <interface type="user">
      <model type="virtio"/>
    </interface>'
  else
    VM_INTERFACE_XML="    <interface type=\"network\">
      <source network=\"$(xml_escape "$VM_NETWORK")\"/>
      <model type=\"virtio\"/>
    </interface>"
  fi
}

create_disk() {
  local disk_dir

  if [[ -n "$VM_DISK_PATH" ]]; then
    command -v qemu-img >/dev/null || die "qemu-img is required when using VM_DISK_PATH"
    [[ ! -e "$VM_DISK_PATH" ]] || die "disk image already exists: $VM_DISK_PATH"
    disk_dir="${VM_DISK_PATH%/*}"
    [[ "$disk_dir" != "$VM_DISK_PATH" ]] || disk_dir="."
    install -d -m 0755 "$disk_dir"
    qemu-img create -f qcow2 "$VM_DISK_PATH" "${VM_DISK_GIB}G" >/dev/null
    DISK_FILE_CREATED=YES
    DISK_PATH="$VM_DISK_PATH"
  else
    [[ -n "$VM_DISK_POOL" ]] || die "VM_DISK_POOL cannot be empty unless VM_DISK_PATH is set"
    virsh --connect "$LIBVIRT_URI" vol-create-as \
      --pool "$VM_DISK_POOL" \
      --name "$VM_DISK_VOLUME" \
      --capacity "${VM_DISK_GIB}G" \
      --format qcow2 >/dev/null
    DISK_VOLUME_CREATED=YES
    DISK_PATH="$(virsh --connect "$LIBVIRT_URI" vol-path --pool "$VM_DISK_POOL" "$VM_DISK_VOLUME")"
  fi
}

[[ -d "$OUT_PATH" ]] || die "missing ISO output directory: $OUT_PATH"
command -v virsh >/dev/null || die "virsh is required"
virsh --connect "$LIBVIRT_URI" uri >/dev/null || die "cannot connect to libvirt at $LIBVIRT_URI"

configure_acceleration
configure_network

ISO_FILE="$(latest_iso)"
DOMAIN_XML="$(mktemp)"
DISK_VOLUME_CREATED=NO
DISK_FILE_CREATED=NO
trap cleanup_on_error ERR
trap 'rm -f "$DOMAIN_XML"' EXIT

if virsh --connect "$LIBVIRT_URI" dominfo "$VM_NAME" >/dev/null 2>&1; then
  die "VM already exists: $VM_NAME"
fi

if [[ -n "$VM_DISK_PATH" && -e "$VM_DISK_PATH" ]]; then
  die "disk image already exists: $VM_DISK_PATH"
fi

if [[ -z "$VM_DISK_PATH" ]] && virsh --connect "$LIBVIRT_URI" vol-info --pool "$VM_DISK_POOL" "$VM_DISK_VOLUME" >/dev/null 2>&1; then
  die "storage volume already exists in pool $VM_DISK_POOL: $VM_DISK_VOLUME"
fi

log "Using ISO: $ISO_FILE"
log "Creating VM: $VM_NAME"
if [[ "$VM_PROFILE" == "gnome-animations" ]]; then
  log "Using GNOME animation testing profile"
fi
if [[ -n "$VM_DISK_PATH" ]]; then
  log "Using disk image: $VM_DISK_PATH"
else
  log "Using storage pool: $VM_DISK_POOL/$VM_DISK_VOLUME"
fi
if [[ "$VM_NETWORK" == "user" ]]; then
  log "Using user-mode networking"
else
  log "Using libvirt network: $VM_NETWORK"
fi
if [[ "$VM_ACCEL_3D_ENABLED" == "YES" ]]; then
  log "Enabling virtio 3D acceleration with $VM_RENDER_NODE"
  if [[ -n "${VM_ACCEL_3D_WARNING:-}" ]]; then
    log "Warning: $VM_ACCEL_3D_WARNING"
  fi
else
  log "Virtio 3D acceleration disabled"
fi

create_disk

cat >"$DOMAIN_XML" <<EOF
<domain type="kvm">
  <name>$(xml_escape "$VM_NAME")</name>
  <memory unit="MiB">$VM_RAM_MB</memory>
  <currentMemory unit="MiB">$VM_RAM_MB</currentMemory>
  <vcpu placement="static">$VM_VCPUS</vcpu>
  <os firmware="efi">
    <type arch="x86_64" machine="q35">hvm</type>
    <boot dev="hd"/>
    <boot dev="cdrom"/>
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
$VM_INTERFACE_XML
$VM_GRAPHICS_XML
    <video>
$VM_VIDEO_MODEL_XML
    </video>
    <channel type="spicevmc">
      <target type="virtio" name="com.redhat.spice.0"/>
    </channel>
  </devices>
</domain>
EOF

virsh --connect "$LIBVIRT_URI" define "$DOMAIN_XML" >/dev/null
DISK_VOLUME_CREATED=NO
DISK_FILE_CREATED=NO

log "Created $VM_NAME"
log "Start it with: virsh --connect $LIBVIRT_URI start $VM_NAME"
log "Open it with: virt-manager --connect $LIBVIRT_URI --show-domain-console $VM_NAME"
