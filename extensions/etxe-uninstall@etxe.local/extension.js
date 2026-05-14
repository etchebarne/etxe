import Clutter from 'gi://Clutter';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import St from 'gi://St';
import Gettext from 'gettext';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as AppDisplay from 'resource:///org/gnome/shell/ui/appDisplay.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as ModalDialog from 'resource:///org/gnome/shell/ui/modalDialog.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';

const MENU_METHOD_CANDIDATES = ['popupMenu', '_buildMenu', '_createMenu'];
const EXTENSION_GETTEXT_DOMAIN = 'app-grid-uninstall';
const GNOME_SHELL_GETTEXT_DOMAIN = 'gnome-shell';
const GNOME_SOFTWARE_GETTEXT_DOMAIN = 'gnome-software';

const PackageType = Object.freeze({
  FLATPAK: 'flatpak',
  PACMAN: 'pacman',
  UNKNOWN: 'unknown',
});

const PROTECTED_APP_IDS = new Set([
  'org.gnome.Settings.desktop',
  'org.gnome.Software.desktop',
  'org.gnome.Extensions.desktop',
]);

const PROTECTED_PACKAGES = new Set([
  'base',
  'base-devel',
  'linux',
  'linux-firmware',
  'systemd',
  'glibc',
  'pacman',
  'sudo',
  'networkmanager',
  'gdm',
  'gnome-shell',
  'gnome-session',
  'gnome-settings-daemon',
  'gnome-control-center',
  'gnome-keyring',
  'dconf',
]);

function getAppName(app) {
  return app?.get_name?.() ?? _('Application');
}

function getAppId(app) {
  return app?.get_id?.() ?? '';
}

function findProgram(name) {
  return GLib.find_program_in_path(name) ?? name;
}

function trimOutput(output) {
  return (output ?? '').trim();
}

function runCommand(argv, env = {}) {
  return new Promise(resolve => {
    let proc;

    try {
      const launcher = Gio.SubprocessLauncher.new(
        Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_PIPE
      );

      for (const [key, value] of Object.entries(env))
        launcher.setenv(key, value, true);

      proc = launcher.spawnv(argv);
    } catch (error) {
      resolve({ok: false, status: -1, stdout: '', stderr: error.message});
      return;
    }

    proc.communicate_utf8_async(null, null, (self, result) => {
      try {
        const [, stdout, stderr] = self.communicate_utf8_finish(result);
        resolve({
          ok: true,
          status: self.get_exit_status(),
          stdout: trimOutput(stdout),
          stderr: trimOutput(stderr),
        });
      } catch (error) {
        resolve({ok: false, status: -1, stdout: '', stderr: error.message});
      }
    });
  });
}

function notify(title, body = '') {
  try {
    Main.notify(title, body);
  } catch (error) {
    console.warn(`[AppGridUninstall] ${title}: ${body} (${error.message})`);
  }
}

function gettextFrom(domain, text) {
  return GLib.dgettext(domain, text);
}

function bindExtensionTranslations(extension) {
  Gettext.bindtextdomain(EXTENSION_GETTEXT_DOMAIN, `${extension.path}/locale`);
}

function _(text) {
  return gettextFrom(EXTENSION_GETTEXT_DOMAIN, text);
}

function formatMessage(text, ...args) {
  let index = 0;
  return text.replace(/%s/g, () => String(args[index++] ?? ''));
}

function cancelLabel() {
  return gettextFrom(GNOME_SHELL_GETTEXT_DOMAIN, 'Cancel');
}

function uninstallLabel() {
  return gettextFrom(GNOME_SOFTWARE_GETTEXT_DOMAIN, 'Uninstall');
}

function lineWrap(label) {
  if (!label.clutter_text)
    return;

  label.clutter_text.set_line_wrap(true);
  label.clutter_text.set_ellipsize(0);
}

function isProtectedApp(app) {
  return PROTECTED_APP_IDS.has(getAppId(app));
}

function isProtectedPackage(pkg) {
  return pkg?.type === PackageType.PACMAN && PROTECTED_PACKAGES.has(pkg.identifier);
}

class PackageDetector {
  async detect(app) {
    const appInfo = app?.get_app_info?.();
    const desktopPath = appInfo?.get_filename?.();

    if (!desktopPath)
      return {type: PackageType.UNKNOWN, identifier: null, desktopPath: null};

    const flatpak = await this._detectFlatpak(app, desktopPath);
    if (flatpak)
      return flatpak;

    const pacman = await this._detectPacman(desktopPath);
    if (pacman)
      return pacman;

    return {type: PackageType.UNKNOWN, identifier: null, desktopPath};
  }

  async _detectFlatpak(app, desktopPath) {
    const appId = getAppId(app).replace(/\.desktop$/, '');
    if (!appId)
      return null;

    const homeDir = GLib.get_home_dir();
    const userFlatpakDir = `${homeDir}/.local/share/flatpak/`;
    const isFlatpakPath = desktopPath.includes('/flatpak/exports/share/applications/');

    if (isFlatpakPath) {
      const scope = desktopPath.startsWith(userFlatpakDir) ? 'user' : 'system';
      return {
        type: PackageType.FLATPAK,
        identifier: appId,
        scope,
        desktopPath,
      };
    }

    if (GLib.find_program_in_path('flatpak') === null)
      return null;

    const result = await runCommand([findProgram('flatpak'), 'info', appId]);
    if (result.ok && result.status === 0)
      return {type: PackageType.FLATPAK, identifier: appId, scope: null, desktopPath};

    return null;
  }

  async _detectPacman(desktopPath) {
    if (GLib.find_program_in_path('pacman') === null)
      return null;

    const pacman = findProgram('pacman');
    const result = await runCommand([pacman, '-Qo', desktopPath], {LC_ALL: 'C'});
    if (!result.ok || result.status !== 0 || !result.stdout)
      return null;

    const identifier = this._parsePacmanOwner(result.stdout);
    if (!identifier)
      return null;

    const originResult = await runCommand([pacman, '-Qm', identifier], {LC_ALL: 'C'});

    return {
      type: PackageType.PACMAN,
      identifier,
      origin: originResult.ok && originResult.status === 0 ? 'foreign' : 'repo',
      desktopPath,
    };
  }

  _parsePacmanOwner(output) {
    const line = output.split('\n').find(entry => entry.includes(' is owned by '));
    if (!line)
      return null;

    const owner = line.split(' is owned by ')[1]?.trim();
    return owner?.split(/\s+/)[0] ?? null;
  }
}

class PacmanPreview {
  async build(pkg) {
    if (pkg.type !== PackageType.PACMAN)
      return [];

    const result = await runCommand([
      findProgram('pacman'),
      '-Rns',
      '--print',
      '--print-format',
      '%n',
      pkg.identifier,
    ], {LC_ALL: 'C'});

    if (!result.ok || result.status !== 0 || !result.stdout)
      return [];

    return result.stdout
      .split('\n')
      .map(line => line.trim())
      .filter(Boolean);
  }
}

class UninstallDialog {
  constructor(app, pkg, pacmanPreview, onConfirm) {
    this._app = app;
    this._pkg = pkg;
    this._pacmanPreview = pacmanPreview;
    this._onConfirm = onConfirm;
  }

  open() {
    const dialog = new ModalDialog.ModalDialog({styleClass: 'prompt-dialog'});
    const appName = getAppName(this._app);

    const layout = new St.BoxLayout({
      style_class: 'prompt-dialog-main-layout',
      style: 'spacing: 18px;',
      vertical: false,
    });

    const icon = this._app?.create_icon_texture?.(64);
    if (icon)
      layout.add_child(icon);

    const textLayout = new St.BoxLayout({
      style: 'spacing: 12px;',
      vertical: true,
    });

    const headline = new St.Label({
      text: formatMessage(_("Uninstall \"%s\"?"), appName),
      style_class: 'prompt-dialog-headline',
    });
    lineWrap(headline);
    textLayout.add_child(headline);

    const body = new St.Label({
      text: this._buildBodyText(),
      style_class: 'prompt-dialog-description',
    });
    lineWrap(body);
    textLayout.add_child(body);

    layout.add_child(textLayout);
    dialog.contentLayout.add_child(layout);

    dialog.addButton({
      label: cancelLabel(),
      action: () => dialog.close(),
      key: Clutter.KEY_Escape,
    });

    dialog.addButton({
      label: uninstallLabel(),
      action: () => {
        dialog.close();
        this._onConfirm();
      },
      key: Clutter.KEY_Return,
      default: true,
    });

    dialog.open();
  }

  _buildBodyText() {
    let body = _('This will remove the app from this computer.');
    body += ` ${_('Your personal files will not be deleted.')}`;

    return body;
  }
}

class BlockedDialog {
  constructor(app, message) {
    this._app = app;
    this._message = message;
  }

  open() {
    const dialog = new ModalDialog.ModalDialog({styleClass: 'prompt-dialog'});

    const headline = new St.Label({
      text: formatMessage(_("Cannot uninstall \"%s\""), getAppName(this._app)),
      style_class: 'prompt-dialog-headline',
    });
    lineWrap(headline);
    dialog.contentLayout.add_child(headline);

    const body = new St.Label({
      text: this._message,
      style_class: 'prompt-dialog-description',
    });
    lineWrap(body);
    dialog.contentLayout.add_child(body);

    dialog.addButton({
      label: _('OK'),
      action: () => dialog.close(),
      key: Clutter.KEY_Return,
      default: true,
    });

    dialog.open();
  }
}

class UninstallManager {
  async start(app) {
    if (!app)
      return;

    if (isProtectedApp(app)) {
      new BlockedDialog(app, _('This is a protected GNOME system application.')).open();
      return;
    }

    const detector = new PackageDetector();
    const pkg = await detector.detect(app);

    if (pkg.type === PackageType.UNKNOWN) {
      notify(
        _('Cannot uninstall application'),
        _('Could not determine whether this launcher belongs to a Flatpak or pacman package.')
      );
      return;
    }

    if (isProtectedPackage(pkg)) {
      new BlockedDialog(
        app,
        formatMessage(
          _('Package %s is protected because removing it can break the desktop or package manager.'),
          pkg.identifier
        )
      ).open();
      return;
    }

    const pacmanPreview = await new PacmanPreview().build(pkg);
    new UninstallDialog(app, pkg, pacmanPreview, () => {
      this._performUninstall(app, pkg);
    }).open();
  }

  async _performUninstall(app, pkg) {
    const appName = getAppName(app);
    const command = this._buildUninstallCommand(pkg);

    if (!command) {
      notify(_('Cannot uninstall application'), _('Required uninstall tool is not installed.'));
      return;
    }

    notify(_('Uninstalling application'), formatMessage(_('Removing %s...'), appName));

    const result = await runCommand(command, {LC_ALL: 'C'});
    if (result.ok && result.status === 0) {
      notify(_('Application uninstalled'), formatMessage(_('%s was removed successfully.'), appName));
      return;
    }

    const details = result.stderr || result.stdout || _('The uninstall command failed.');
    notify(formatMessage(_('Failed to uninstall %s'), appName), details);
  }

  _buildUninstallCommand(pkg) {
    if (pkg.type === PackageType.FLATPAK) {
      if (GLib.find_program_in_path('flatpak') === null)
        return null;

      const argv = [findProgram('flatpak'), 'uninstall', '--noninteractive'];
      if (pkg.scope === 'user')
        argv.push('--user');
      else if (pkg.scope === 'system')
        argv.push('--system');
      argv.push(pkg.identifier);
      return argv;
    }

    if (pkg.type === PackageType.PACMAN) {
      if (GLib.find_program_in_path('pkexec') === null || GLib.find_program_in_path('pacman') === null)
        return null;

      return [findProgram('pkexec'), findProgram('pacman'), '-Rns', '--noconfirm', pkg.identifier];
    }

    return null;
  }
}

class AppGridMenuPatcher {
  constructor() {
    this._isPatched = false;
    this._originalMethod = null;
    this._patchedMethodName = null;
    this._entries = [];
    this._manager = new UninstallManager();
  }

  enable() {
    if (this._isPatched)
      return;

    const prototype = AppDisplay.AppIcon?.prototype;
    if (!prototype)
      return;

    const methodName = MENU_METHOD_CANDIDATES.find(name => typeof prototype[name] === 'function');
    if (!methodName)
      return;

    this._patchedMethodName = methodName;
    this._originalMethod = prototype[methodName];

    const patcher = this;
    prototype[methodName] = function (...args) {
      const result = patcher._originalMethod.apply(this, args);
      patcher._inject(this);
      return result;
    };

    this._isPatched = true;
  }

  disable() {
    if (!this._isPatched)
      return;

    const prototype = AppDisplay.AppIcon?.prototype;
    if (prototype && this._patchedMethodName && this._originalMethod)
      prototype[this._patchedMethodName] = this._originalMethod;

    for (const entry of this._entries) {
      try {
        if (entry.activateId)
          entry.item.disconnect(entry.activateId);
      } catch (_) {}

      try {
        entry.separator.destroy();
        entry.item.destroy();
      } catch (_) {}

      if (entry.menu)
        delete entry.menu._etxeAppGridUninstallInjected;
    }

    this._entries = [];
    this._isPatched = false;
    this._originalMethod = null;
    this._patchedMethodName = null;
  }

  _inject(appIcon) {
    const menu = appIcon?._menu;
    const app = appIcon?.app ?? appIcon?._app;

    if (!menu || !app || menu._etxeAppGridUninstallInjected)
      return;

    const separator = new PopupMenu.PopupSeparatorMenuItem();
    const item = new PopupMenu.PopupMenuItem(`${uninstallLabel()}...`);
    const activateId = item.connect('activate', () => {
      this._manager.start(app).catch(error => {
        notify(_('Cannot uninstall application'), error.message);
      });
    });

    if (isProtectedApp(app)) {
      item.setSensitive(false);
      item.label.set_text(`${uninstallLabel()} (${_('protected')})`);
    }

    menu.addMenuItem(separator);
    menu.addMenuItem(item);
    menu._etxeAppGridUninstallInjected = true;

    this._entries.push({menu, separator, item, activateId});
  }
}

export default class AppGridUninstallExtension extends Extension {
  enable() {
    bindExtensionTranslations(this);
    this._patcher = new AppGridMenuPatcher();
    this._patcher.enable();
  }

  disable() {
    this._patcher?.disable();
    this._patcher = null;
  }
}
