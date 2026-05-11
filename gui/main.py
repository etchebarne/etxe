#!/usr/bin/env python3

import json
import os
import re
import shlex
import subprocess
from pathlib import Path

from PySide6.QtCore import QObject, Property, Qt, QTimer, QUrl, Signal, Slot
from PySide6.QtGui import QCursor, QFont, QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine


ENV_PATH = Path("/etc/etxe/install.env")
LOG_PATH = Path("/var/log/etxe-install.log")

KEYMAP_NAMES = {
    "am": "Armenian",
    "at": "German (Austria)",
    "az": "Azerbaijani",
    "be": "Belgian",
    "bg": "Bulgarian",
    "br": "Portuguese (Brazil)",
    "by": "Belarusian",
    "ca": "French (Canada)",
    "cf": "French (Canada)",
    "cz": "Czech",
    "de": "German",
    "dk": "Danish",
    "es": "Spanish",
    "et": "Estonian",
    "fi": "Finnish",
    "fr": "French",
    "gr": "Greek",
    "hu": "Hungarian",
    "ie": "Irish",
    "il": "Hebrew",
    "is": "Icelandic",
    "it": "Italian",
    "jp": "Japanese",
    "la": "Spanish (Latin America)",
    "lt": "Lithuanian",
    "lv": "Latvian",
    "mk": "Macedonian",
    "nl": "Dutch",
    "no": "Norwegian",
    "pl": "Polish",
    "pt": "Portuguese",
    "ro": "Romanian",
    "ru": "Russian",
    "se": "Swedish",
    "sg": "Swiss German",
    "sk": "Slovak",
    "tr": "Turkish",
    "ua": "Ukrainian",
    "uk": "English (United Kingdom)",
    "us": "English (United States)",
}


class InstallerBackend(QObject):
    disksChanged = Signal()
    wifiNetworksChanged = Signal()
    logTextChanged = Signal()
    installStateChanged = Signal()
    installPhaseChanged = Signal()
    networkMessageChanged = Signal()
    ethernetChanged = Signal()
    installFinished = Signal(bool, str)

    def __init__(self):
        super().__init__()
        self._disks = []
        self._wifi_networks = []
        self._locales = self._load_locales()
        self._keymaps = self._load_keymaps()
        self._timezones = self._load_timezones()
        self._has_ethernet = self._detect_ethernet()
        self._log_text = ""
        self._install_state = "idle"
        self._install_phase = "Preparing the installer"
        self._network_message = ""
        self._status_timer = QTimer(self)
        self._status_timer.setInterval(1000)
        self._status_timer.timeout.connect(self.refreshInstallStatus)
        self.refreshDisks()

    @Property("QVariantList", notify=disksChanged)
    def disks(self):
        return self._disks

    @Property("QVariantList", notify=wifiNetworksChanged)
    def wifiNetworks(self):
        return self._wifi_networks

    @Property(str, notify=logTextChanged)
    def logText(self):
        return self._log_text

    @Property(str, notify=installStateChanged)
    def installState(self):
        return self._install_state

    @Property(str, notify=installPhaseChanged)
    def installPhase(self):
        return self._install_phase

    @Property(str, notify=networkMessageChanged)
    def networkMessage(self):
        return self._network_message

    @Property(bool, notify=ethernetChanged)
    def hasEthernet(self):
        return self._has_ethernet

    @Property("QVariantList", constant=True)
    def locales(self):
        return self._locales

    @Property("QVariantList", constant=True)
    def keymaps(self):
        return self._keymaps

    @Property("QVariantList", constant=True)
    def timezones(self):
        return self._timezones

    def _option(self, value, label=None):
        return {"value": value, "label": label or value}

    def _decode_i18n_value(self, raw_value):
        chunks = re.findall(r'"([^"]*)"', raw_value)
        value = "".join(chunks) if chunks else raw_value.strip()

        def replace_codepoint(match):
            return chr(int(match.group(1), 16))

        value = re.sub(r"<U([0-9A-Fa-f]{4,6})>", replace_codepoint, value)
        value = value.replace("<space>", " ")
        return value.strip()

    def _locale_metadata(self, locale_name):
        locale_base = locale_name.split(".", 1)[0].split("@", 1)[0]
        locale_file = Path("/usr/share/i18n/locales") / locale_base
        metadata = {}

        if not locale_file.exists():
            return metadata

        for raw_line in locale_file.read_text(errors="replace").splitlines():
            line = raw_line.strip()
            for field in ("language", "territory"):
                if line.startswith(field + " ") or line.startswith(field + "\t"):
                    metadata[field] = self._decode_i18n_value(line[len(field):])

        return metadata

    def _locale_label(self, locale_name):
        metadata = self._locale_metadata(locale_name)
        language = metadata.get("language")
        territory = metadata.get("territory")

        if language and territory:
            return f"{language} ({territory})"
        if language:
            return language

        return locale_name

    def _load_locales(self):
        locale_gen = Path("/etc/locale.gen")
        locales = []
        seen = set()

        if locale_gen.exists():
            for raw_line in locale_gen.read_text(errors="replace").splitlines():
                line = raw_line.strip()
                if not line or line.startswith("##"):
                    continue
                line = line.removeprefix("#").strip()
                parts = line.split()
                if len(parts) < 2 or parts[1].upper() != "UTF-8":
                    continue
                locale = parts[0]
                if locale in seen:
                    continue
                seen.add(locale)
                locales.append(self._option(locale, self._locale_label(locale)))

        if not locales:
            locales = [self._option("en_US.UTF-8", "en US.UTF-8")]

        label_counts = {}
        for item in locales:
            label_counts[item["label"]] = label_counts.get(item["label"], 0) + 1

        for item in locales:
            if label_counts[item["label"]] > 1:
                item["label"] = f"{item['label']} ({item['value']})"

        return sorted(locales, key=lambda item: item["label"].casefold())

    def _keymap_label(self, keymap):
        base = keymap.split("-", 1)[0]
        name = KEYMAP_NAMES.get(keymap) or KEYMAP_NAMES.get(base)

        if name:
            return name if keymap == base else f"{name} ({keymap})"

        return f"{keymap.replace('-', ' ').replace('_', ' ').title()} ({keymap})"

    def _load_keymaps(self):
        result = self._run(["localectl", "list-keymaps"])
        keymaps = [line.strip() for line in result.stdout.splitlines() if line.strip()]

        if not keymaps:
            keymaps = ["us"]

        options = [self._option(keymap, self._keymap_label(keymap)) for keymap in set(keymaps)]
        return sorted(options, key=lambda item: item["label"].casefold())

    def _load_timezones(self):
        result = self._run(["timedatectl", "list-timezones"])
        timezones = [line.strip() for line in result.stdout.splitlines() if line.strip()]

        if not timezones:
            timezones = ["UTC"]

        return [self._option(timezone) for timezone in sorted(set(timezones), key=str.casefold)]

    def _detect_ethernet(self):
        result = self._run(["nmcli", "-t", "-f", "TYPE,STATE", "device", "status"])
        if result.returncode == 0:
            for line in result.stdout.splitlines():
                device_type, _, state = line.partition(":")
                if device_type == "ethernet" and state == "connected":
                    return True

        for device in Path("/sys/class/net").glob("*"):
            if device.name == "lo" or (device / "wireless").exists():
                continue
            carrier = device / "carrier"
            if carrier.exists() and carrier.read_text(errors="ignore").strip() == "1":
                return True

        return False

    def _set_install_state(self, state):
        if self._install_state != state:
            self._install_state = state
            self.installStateChanged.emit()

    def _set_install_phase(self, phase):
        if self._install_phase != phase:
            self._install_phase = phase
            self.installPhaseChanged.emit()

    def _update_install_phase_from_log(self, log_text):
        checks = [
            ("Installation finished successfully", "Finishing up"),
            ("Enabling GDM", "Preparing the sign-in screen"),
            ("Creating user", "Creating your account"),
            ("Configuring PipeWire", "Setting up audio"),
            ("Configuring NetworkManager", "Setting up networking"),
            ("Installing systemd-boot", "Setting up boot"),
            ("Configuring locale", "Applying your region settings"),
            ("Generating fstab", "Writing disk configuration"),
            ("Installing native packages", "Installing the desktop system"),
            ("Mounting filesystems", "Preparing the new system"),
            ("Creating Btrfs subvolumes", "Preparing the filesystem"),
            ("Formatting filesystems", "Formatting the disk"),
            ("Partitioning", "Partitioning the disk"),
            ("Running preflight checks", "Checking this computer"),
        ]

        for needle, phase in checks:
            if needle in log_text:
                self._set_install_phase(phase)
                return

    def _set_network_message(self, message):
        self._network_message = message
        self.networkMessageChanged.emit()

    def _run(self, args, check=False):
        return subprocess.run(args, check=check, text=True, capture_output=True)

    def _split_nmcli_terse(self, line):
        fields = []
        current = []
        escaped = False

        for character in line:
            if escaped:
                current.append(character)
                escaped = False
            elif character == "\\":
                escaped = True
            elif character == ":":
                fields.append("".join(current))
                current = []
            else:
                current.append(character)

        if escaped:
            current.append("\\")

        fields.append("".join(current))
        return fields

    def _systemctl_show(self):
        result = self._run([
            "systemctl",
            "show",
            "etxe-install.service",
            "-p",
            "ActiveState",
            "-p",
            "Result",
            "-p",
            "ExecMainStatus",
        ])
        values = {}
        for line in result.stdout.splitlines():
            if "=" in line:
                key, value = line.split("=", 1)
                values[key] = value
        return values

    def _read_log(self):
        if not LOG_PATH.exists():
            return "Waiting for installer output..."

        data = LOG_PATH.read_text(errors="replace")
        return data[-12000:]

    def _write_env(self, config):
        ENV_PATH.parent.mkdir(parents=True, exist_ok=True)
        values = {
            "DISK": config.get("disk", ""),
            "HOSTNAME": config.get("hostname", "etxe"),
            "USERNAME": config.get("username", "martin"),
            "USER_PASSWORD": config.get("password", ""),
            "TIMEZONE": config.get("timezone", "Europe/Madrid"),
            "LOCALE": config.get("locale", "en_US.UTF-8"),
            "KEYMAP": config.get("keymap", "us"),
            "CONFIRM_WIPE": "YES",
            "ETXE_REQUIRE_OFFLINE_REPO": "YES",
            "ETXE_REQUIRE_OFFLINE_FLATPAKS": "YES",
            "ETXE_AUTOLOGIN": "YES" if config.get("autologin", True) else "NO",
            "ETXE_FINISH_ACTION": "none",
        }

        lines = [f"{key}={shlex.quote(str(value))}" for key, value in values.items()]
        try:
            os.chmod(ENV_PATH, 0o600)
        except FileNotFoundError:
            pass

        temp_path = ENV_PATH.with_name(f".{ENV_PATH.name}.tmp")
        fd = os.open(temp_path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        try:
            os.fchmod(fd, 0o600)
            env_file = os.fdopen(fd, "w")
            fd = None
            with env_file:
                env_file.write("\n".join(lines) + "\n")
            os.replace(temp_path, ENV_PATH)
            os.chmod(ENV_PATH, 0o600)
        except Exception:
            if fd is not None:
                os.close(fd)
            try:
                temp_path.unlink()
            except FileNotFoundError:
                pass
            raise

    def _remove_env(self):
        try:
            ENV_PATH.unlink()
        except FileNotFoundError:
            pass

    @Slot()
    def refreshDisks(self):
        try:
            output = subprocess.check_output([
                "lsblk",
                "-J",
                "-b",
                "-o",
                "NAME,PATH,SIZE,MODEL,TYPE,RM,RO",
            ], text=True)
            data = json.loads(output)
        except Exception:
            data = {"blockdevices": []}

        disks = []
        for device in data.get("blockdevices", []):
            if device.get("type") != "disk":
                continue
            if device.get("rm") or device.get("ro"):
                continue

            size = int(device.get("size") or 0)
            if size < 8 * 1024**3:
                continue

            gib = size / 1024**3
            model = (device.get("model") or "Virtual disk").strip()
            path = device.get("path") or f"/dev/{device.get('name')}"
            disks.append({
                "path": path,
                "label": f"{path} - {gib:.1f} GiB",
                "model": model,
                "size": f"{gib:.1f} GiB",
            })

        self._disks = disks
        self.disksChanged.emit()

    @Slot()
    def refreshWifi(self):
        has_ethernet = self._detect_ethernet()
        if has_ethernet != self._has_ethernet:
            self._has_ethernet = has_ethernet
            self.ethernetChanged.emit()

        result = self._run([
            "nmcli",
            "-t",
            "--escape",
            "yes",
            "-f",
            "SSID,SIGNAL,SECURITY",
            "dev",
            "wifi",
            "list",
            "--rescan",
            "yes",
        ])
        networks = []
        seen = set()

        if result.returncode != 0:
            self._wifi_networks = []
            self.wifiNetworksChanged.emit()
            self._set_network_message("Wi-Fi is not available. Continue with Ethernet." if self._has_ethernet else "Wi-Fi is not available. You can continue offline.")
            return

        for line in result.stdout.splitlines():
            parts = self._split_nmcli_terse(line)
            if len(parts) < 2:
                continue
            ssid = parts[0].strip()
            if not ssid or ssid in seen:
                continue
            seen.add(ssid)
            signal = parts[1].strip()
            security = ":".join(parts[2:]).strip() if len(parts) > 2 else ""
            networks.append({"ssid": ssid, "signal": signal, "security": security or "Open"})

        self._wifi_networks = networks
        self.wifiNetworksChanged.emit()
        self._set_network_message("Select a network or continue with Ethernet." if self._has_ethernet else "Select a network or continue offline.")

    @Slot(str, str)
    def connectWifi(self, ssid, password):
        if not ssid:
            self._set_network_message("Select a Wi-Fi network first.")
            return

        command = ["nmcli", "dev", "wifi", "connect", ssid]
        if password:
            command.extend(["password", password])

        result = self._run(command)
        if result.returncode == 0:
            self._set_network_message(f"Connected to {ssid}.")
        else:
            message = result.stderr.strip() or result.stdout.strip() or "Could not connect."
            self._set_network_message(message)

    @Slot("QVariantMap", result=bool)
    def startInstall(self, config):
        if not config.get("disk"):
            self._set_install_state("Select an installation disk.")
            return False
        if not config.get("username"):
            self._set_install_state("Enter a username.")
            return False
        if not config.get("password"):
            self._set_install_state("Enter a password.")
            return False

        try:
            self._write_env(config)
        except OSError as error:
            self._set_install_state(f"Could not save installer settings: {error}")
            return False

        LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
        LOG_PATH.write_text("")

        self._run(["systemctl", "reset-failed", "etxe-install.service"])
        result = self._run(["systemctl", "start", "--no-block", "etxe-install.service"])
        if result.returncode != 0:
            self._remove_env()
            self._set_install_state(result.stderr.strip() or "Could not start installer.")
            return False

        self._set_install_state("Installing Etxe...")
        self._set_install_phase("Checking this computer")
        self._status_timer.start()
        return True

    @Slot()
    def refreshInstallStatus(self):
        log_text = self._read_log()
        if log_text != self._log_text:
            self._log_text = log_text
            self.logTextChanged.emit()
            self._update_install_phase_from_log(log_text)

        values = self._systemctl_show()
        active_state = values.get("ActiveState", "")
        result = values.get("Result", "")
        status = values.get("ExecMainStatus", "")

        if active_state in ("active", "activating"):
            self._set_install_state("Installing Etxe...")
            return

        if result == "success" and status == "0":
            self._status_timer.stop()
            self._set_install_state("Installation complete")
            self._set_install_phase("Installation complete")
            self.installFinished.emit(True, "Etxe was installed successfully.")
        elif result and result != "success":
            self._status_timer.stop()
            self._set_install_state("Installation failed")
            self._set_install_phase("Something went wrong")
            self.installFinished.emit(False, "Installation failed. The details are available below.")

    @Slot(str)
    def applyKeymap(self, keymap):
        if keymap:
            self._run(["localectl", "set-keymap", keymap])

    @Slot()
    def reboot(self):
        self._run(["systemctl", "reboot"])

    @Slot()
    def poweroff(self):
        self._run(["systemctl", "poweroff"])


def main():
    os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")
    app = QGuiApplication([])
    app.setOverrideCursor(QCursor(Qt.ArrowCursor))
    app.setFont(QFont("Red Hat Display", 12))
    engine = QQmlApplicationEngine()
    backend = InstallerBackend()
    engine.rootContext().setContextProperty("backend", backend)
    qml_path = Path(__file__).with_name("ui").joinpath("Main.qml")
    engine.load(QUrl.fromLocalFile(str(qml_path)))

    if not engine.rootObjects():
        raise SystemExit(1)

    raise SystemExit(app.exec())


if __name__ == "__main__":
    main()
