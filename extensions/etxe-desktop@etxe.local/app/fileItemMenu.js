/* DING: Desktop Icons New Generation for GNOME Shell
 *
 * Copyright (C) 2021 Sergio Costas (rastersoft@gmail.com)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, version 3 of the License.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
'use strict';
const DBusUtils = imports.dbusUtils;
const GLib = imports.gi.GLib;
const Gdk = imports.gi.Gdk;
const Gtk = imports.gi.Gtk;
const Gio = imports.gi.Gio;

const DesktopIconsUtil = imports.desktopIconsUtil;
const Prefs = imports.preferences;
const ShowErrorPopup = imports.showErrorPopup;
const SignalManager = imports.signalManager;

const Gettext = imports.gettext.domain('ding');

const _ = Gettext.gettext;

var FileItemMenu = class {
    constructor(desktopManager) {
        this._currentFileItem = null;
        this._desktopManager = desktopManager;
        DBusUtils.GnomeArchiveManager.connect('changed-status', () => {
            // wait a second to ensure that everything has settled
            GLib.timeout_add(GLib.PRIORITY_DEFAULT, 1000, () => {
                this._getExtractionSupportedTypes();
                return false;
            });
        });
        this._askedSupportedTypes = false;
    }

    _getExtractionSupportedTypes() {
        this._decompressibleTypes = [];
        try {
            if (DBusUtils.GnomeArchiveManager.isAvailable) {
                DBusUtils.GnomeArchiveManager.proxy.GetSupportedTypesRemote('extract',
                    (result, error) => {
                        if (error) {
                            console.error(error, "Can't get the extractable types; ensure that File-Roller is installed.\n");
                            return;
                        }
                        for (let key of result.values()) {
                            for (let type of key.values()) {
                                this._decompressibleTypes.push(Object.values(type)[0]);
                            }
                        }
                    }
                );
            }
            this._askedSupportedTypes = true;
        } catch (e) {
            console.error(e, 'Error while getting supported types.');
        }
    }

    refreshedIcons() {
        if (!this._currentFileItem) {
            return;
        }
        this._currentFileItem = this._desktopManager.getFileItemFromURI(this._currentFileItem.uri);
    }

    showMenu(fileItem, event, atWidget = false) {
        if (!this._askedSupportedTypes) {
            this._getExtractionSupportedTypes();
        }
        this._currentFileItem = fileItem;

        let selectedItemsNum = this._desktopManager.getNumberOfSelectedItems();
        this._showNativeMenu(fileItem, event, selectedItemsNum);
    }

    _showNativeMenu(fileItem, event, selectedItemsNum) {
        const [x, y] = this._getEventGlobalCoordinates(fileItem, event);
        const items = this._buildNativeMenuItems(fileItem, selectedItemsNum);

        return this._desktopManager.showNativeMenu(x, y, items);
    }

    _getEventGlobalCoordinates(fileItem, event) {
        try {
            const [ok, x, y] = event.get_root_coords();
            if (ok)
                return [x, y];
        } catch (e) {}

        const coordinates = fileItem.getCoordinates();
        if (coordinates)
            return coordinates.slice(0, 2);

        return [0, 0];
    }

    _buildNativeMenuItems(fileItem, selectedItemsNum) {
        const item = this._desktopManager._nativeMenuItem.bind(this._desktopManager);
        const separator = this._desktopManager._nativeMenuSeparator.bind(this._desktopManager);
        const items = [];

        if (!fileItem.isStackMarker) {
            items.push(item(selectedItemsNum > 1 ? _('Open All...') : _('Open'), 'file-open'));
        }

        let keepStacked = Prefs.desktopSettings.get_boolean('keep-stacked');
        if (keepStacked && !fileItem.stackUnique) {
            if (!fileItem.isSpecial && !fileItem.isDirectory && !fileItem.isValidDesktopFile) {
                let unstackList = Prefs.getUnstackList();
                let typeInList = unstackList.includes(fileItem.attributeContentType);
                items.push(item(typeInList ? _('Stack This Type') : _('Unstack This Type'), 'file-stack-toggle'));
            }
        }

        if (fileItem.isAllSelectable && !fileItem.isStackMarker) {
            items.push(item(
                selectedItemsNum > 1 ? _('Open All With Other Application...') : _('Open With Other Application'),
                'file-open-with',
                selectedItemsNum > 0
            ));

            if (DBusUtils.discreteGpuAvailable && fileItem.trustedDesktopFile && (selectedItemsNum == 1)) {
                items.push(item(_('Launch using Dedicated Graphics Card'), 'file-launch-dgpu'));
            }

            items.push(separator());

            if (fileItem.attributeCanExecute && !fileItem.isDirectory && !fileItem.isValidDesktopFile && fileItem.execLine && Gio.content_type_can_be_executable(fileItem.attributeContentType)) {
                items.push(item(_('Run as a program'), 'file-run-program'));
                items.push(separator());
            }

            let allowCutCopyTrash = this._desktopManager.checkIfSpecialFilesAreSelected();
            items.push(item(_('Cut'), 'file-cut', !allowCutCopyTrash));
            items.push(item(_('Copy'), 'file-copy', !allowCutCopyTrash));

            if (fileItem.canRename && (selectedItemsNum == 1)) {
                items.push(item(_('Rename…'), 'file-rename'));
            }

            items.push(separator());
            items.push(item(_('Move to Trash'), 'file-trash', !allowCutCopyTrash));

            if (Prefs.nautilusSettings.get_boolean('show-delete-permanently')) {
                items.push(item(_('Delete permanently'), 'file-delete-permanently', !allowCutCopyTrash));
            }

            if (fileItem.isValidDesktopFile && !this._desktopManager.writableByOthers && !fileItem.writableByOthers && (selectedItemsNum == 1)) {
                items.push(separator());
                items.push(item(fileItem.trustedDesktopFile ? _("Don't Allow Launching") : _('Allow Launching'), 'file-allow-launching'));
            }
        }

        if (fileItem.isTrash) {
            items.push(separator());
            items.push(item(_('Empty Trash'), 'file-empty-trash'));
        }

        if (fileItem.isDrive) {
            items.push(separator());
            if (fileItem.canEject)
                items.push(item(_('Eject'), 'file-eject'));
            if (fileItem.canUnmount)
                items.push(item(_('Unmount'), 'file-unmount'));
        }

        if (fileItem.isAllSelectable && !this._desktopManager.checkIfSpecialFilesAreSelected() && (selectedItemsNum >= 1)) {
            items.push(separator());

            if (this._getExtractableAutoAr() || this._getExtractable()) {
                items.push(item(_('Extract Here'), 'file-extract-here'));
            }

            if (selectedItemsNum == 1 && this._getExtractable()) {
                items.push(item(_('Extract To...'), 'file-extract-to'));
            }

            if (!fileItem.isDirectory) {
                items.push(item(_('Send to...'), 'file-send-to'));
            }

            if (this._desktopManager.getCurrentSelection().every(f => f.isDirectory)) {
                items.push(item(
                    Gettext.ngettext('Compress {0} folder', 'Compress {0} folders', selectedItemsNum).replace('{0}', selectedItemsNum),
                    'file-compress'
                ));
            } else {
                items.push(item(
                    Gettext.ngettext('Compress {0} file', 'Compress {0} files', selectedItemsNum).replace('{0}', selectedItemsNum),
                    'file-compress'
                ));
            }

            items.push(item(
                Gettext.ngettext('New Folder with {0} item', 'New Folder with {0} items', selectedItemsNum).replace('{0}', selectedItemsNum),
                'file-new-folder-selection'
            ));
            items.push(separator());
        }

        if (!fileItem.isStackMarker) {
            items.push(item(selectedItemsNum > 1 ? _('Common Properties') : _('Properties'), 'file-properties'));
            items.push(separator());
            items.push(item(selectedItemsNum > 1 ? _('Show All in Files') : _('Show in Files'), 'file-show-in-files'));
        }

        if (fileItem.isDirectory && (fileItem.path != null) && (selectedItemsNum == 1)) {
            items.push(item(_('Open in Terminal'), 'file-open-terminal'));
        }

        return items;
    }

    activateNativeMenuAction(action) {
        if (!this._currentFileItem)
            return;

        switch (action) {
        case 'open':
            this._doMultiOpen();
            break;
        case 'stack-toggle': {
            const unstackList = Prefs.getUnstackList();
            const type = this._currentFileItem.attributeContentType;
            this._desktopManager.onToggleStackUnstackThisTypeClicked(type, unstackList.includes(type), unstackList);
            break;
        }
        case 'open-with':
            this._doOpenWith();
            break;
        case 'launch-dgpu':
            this._currentFileItem.doDiscreteGpu();
            break;
        case 'run-program':
            DesktopIconsUtil.spawnCommandLine(`"${this._currentFileItem.execLine}"`);
            break;
        case 'cut':
            this._desktopManager.doCut();
            break;
        case 'copy':
            this._desktopManager.doCopy();
            break;
        case 'rename':
            this._desktopManager.doRename(this._currentFileItem, false);
            break;
        case 'trash':
            this._desktopManager.doTrash();
            break;
        case 'delete-permanently':
            this._desktopManager.doDeletePermanently();
            break;
        case 'allow-launching':
            this._currentFileItem.onAllowDisallowLaunchingClicked();
            break;
        case 'empty-trash':
            this._desktopManager.doEmptyTrash();
            break;
        case 'eject':
            this._currentFileItem.eject();
            break;
        case 'unmount':
            this._currentFileItem.unmount();
            break;
        case 'extract-here':
            if (this._getExtractableAutoAr()) {
                this._desktopManager.getCurrentSelection(false).forEach(f =>
                    this._desktopManager.autoAr.extractFile(f.fileName));
            } else {
                this._extractFileFromSelection(true);
            }
            break;
        case 'extract-to':
            this._extractFileFromSelection(false);
            break;
        case 'send-to':
            this._mailFilesFromSelection();
            break;
        case 'compress':
            this._doCompressFilesFromSelection();
            break;
        case 'new-folder-selection':
            this._doNewFolderFromSelection(this._currentFileItem);
            break;
        case 'properties':
            this._onPropertiesClicked();
            break;
        case 'show-in-files':
            this._onShowInFilesClicked();
            break;
        case 'open-terminal':
            DesktopIconsUtil.launchTerminal(this._currentFileItem.path, null);
            break;
        }
    }

    _onPropertiesClicked() {
        let propertiesFileList = this._desktopManager.getCurrentSelection(true);
        const timestamp = Gtk.get_current_event_time();
        DBusUtils.RemoteFileOperations.ShowItemPropertiesRemote(propertiesFileList, timestamp);
    }

    _onShowInFilesClicked() {
        let showInFilesList = this._desktopManager.getCurrentSelection(true);
        if (this._desktopManager.useNemo) {
            try {
                for (let element of showInFilesList) {
                    DesktopIconsUtil.trySpawn(GLib.get_home_dir(), ['nemo', element], DesktopIconsUtil.getFilteredEnviron());
                }
                return;
            } catch (err) {
                console.error(err, 'Error trying to launch Nemo.');
            }
        }
        const timestamp = Gtk.get_current_event_time();
        DBusUtils.RemoteFileOperations.ShowItemsRemote(showInFilesList, timestamp);
    }

    _doMultiOpen() {
        for (let fileItem of this._desktopManager.getCurrentSelection(false)) {
            fileItem.unsetSelected();
            fileItem.doOpen();
        }
    }

    _doOpenWith() {
        let fileItems = this._desktopManager.getCurrentSelection(false);
        if (fileItems) {
            const context = Gdk.Display.get_default().get_app_launch_context();
            context.set_timestamp(Gtk.get_current_event_time());
            let mimetype = Gio.content_type_guess(fileItems[0].fileName, null)[0];
            if (fileItems[0].isDirectory) {
                mimetype = 'inode/directory';
            }
            let chooser = Gtk.AppChooserDialog.new_for_content_type(null,
                Gtk.DialogFlags.MODAL + Gtk.DialogFlags.USE_HEADER_BAR,
                mimetype);
            chooser.set_type_hint(Gdk.WindowTypeHint.NORMAL);
            const windowGroup = new Gtk.WindowGroup();
            windowGroup.add_window(chooser);
            let signals = new SignalManager.SignalManager();
            chooser.show_all();
            signals.connectSignal(chooser, 'close', () => {
                chooser.response(Gtk.ResponseType.CANCEL);
            });
            signals.connectSignal(chooser, 'response', (actor, retval) => {
                if (retval == Gtk.ResponseType.OK) {
                    let appInfo = chooser.get_app_info();
                    if (appInfo) {
                        let fileList = [];
                        for (let item of fileItems) {
                            fileList.push(item.file);
                        }
                        appInfo.launch(fileList, context);
                    }
                }
                chooser.hide();
                signals.disconnectAllSignals();
                chooser = null;
                signals = null;
            });
        }
    }

    _extractFileFromSelection(extractHere) {
        let extractFileItemURI;
        let extractFolderName;
        let position;
        const header = _('No Extraction Folder');
        const text = _('Unable to extract File, extraction Folder Does not Exist');

        for (let fileItem of this._desktopManager.getCurrentSelection(false)) {
            extractFileItemURI = fileItem.file.get_uri();
            extractFolderName = fileItem.fileName;
            position = fileItem.getCoordinates().slice(0, 2);
            fileItem.unsetSelected();
        }

        if (extractHere) {
            extractFolderName = DesktopIconsUtil.getFileExtensionOffset(extractFolderName).basename;
            const targetURI = this._desktopManager.doNewFolder(position, extractFolderName, {rename: false});
            if (targetURI) {
                DBusUtils.RemoteFileOperations.ExtractRemote(extractFileItemURI, targetURI, true);
            } else {
                this._desktopManager.DBusManager.doNotify(header, text);
            }
            return;
        }

        const dialog = new Gtk.FileChooserDialog({
            title: _('Select Extract Destination'),
            modal: true,
            type_hint: Gdk.WindowTypeHint.NORMAL,
        });
        const windowGroup = new Gtk.WindowGroup();
        windowGroup.add_window(dialog);
        dialog.set_action(Gtk.FileChooserAction.SELECT_FOLDER);
        dialog.set_create_folders(true);
        dialog.set_current_folder_uri(DesktopIconsUtil.getDesktopDir().get_uri());
        dialog.add_button(_('Cancel'), Gtk.ResponseType.CANCEL);
        dialog.add_button(_('Select'), Gtk.ResponseType.ACCEPT);
        dialog.show_all();
        dialog.connect('close', () => {
            dialog.response(Gtk.ResponseType.CANCEL);
        });
        dialog.connect('response', (actor, response) => {
            if (response === Gtk.ResponseType.ACCEPT) {
                const folder = dialog.get_uri();
                if (folder) {
                    DBusUtils.RemoteFileOperations.ExtractRemote(extractFileItemURI, folder, true);
                } else {
                    this._desktopManager.DBusManager.doNotify(header, text);
                }
            }
            dialog.destroy();
        });
    }

    _getExtractableAutoAr() {
        let fileList = this._desktopManager.getCurrentSelection(false);
        if (DBusUtils.GnomeArchiveManager.isAvailable && (fileList.length == 1)) {
            return false;
        }
        for (let item of fileList) {
            if (!this._desktopManager.autoAr.fileIsCompressed(item.fileName)) {
                return false;
            }
        }
        return true;
    }

    _getExtractable() {
        for (let item of this._desktopManager.getCurrentSelection(false)) {
            return this._decompressibleTypes.includes(item.attributeContentType);
        }
        return false;
    }

    _mailFilesFromSelection() {
        if (this._desktopManager.checkIfDirectoryIsSelected()) {
            let WindowError = new ShowErrorPopup.ShowErrorPopup(_('Can not email a Directory'),
                _('Selection includes a Directory, compress the directory to a file first.'),
                false);
            WindowError.run();
            return;
        }
        let xdgEmailCommand = [];
        xdgEmailCommand.push('xdg-email');
        for (let fileItem of this._desktopManager.getCurrentSelection(false)) {
            fileItem.unsetSelected();
            xdgEmailCommand.push('--attach');
            xdgEmailCommand.push(fileItem.file.get_path());
        }
        DesktopIconsUtil.trySpawn(null, xdgEmailCommand);
    }

    _doCompressFilesFromSelection() {
        let desktopFolder = DesktopIconsUtil.getDesktopDir();
        if (desktopFolder) {
            if (DBusUtils.GnomeArchiveManager.isAvailable) {
                const toCompress = this._desktopManager.getCurrentSelection(true);
                DBusUtils.RemoteFileOperations.CompressRemote(toCompress, desktopFolder.get_uri(), true);
            } else {
                const toCompress = this._desktopManager.getCurrentSelection(false);
                this._desktopManager.autoAr.compressFileItems(toCompress, desktopFolder.get_path());
            }
        }
        this._desktopManager.unselectAll();
    }

    _doNewFolderFromSelection(clickedItem) {
        if (!clickedItem) {
            return;
        }
        let position = clickedItem.savedCoordinates;
        let newFolderFileItems = this._desktopManager.getCurrentSelection(true);
        this._desktopManager.unselectAll();
        clickedItem.removeFromGrid(true);
        let newFolder = this._desktopManager.doNewFolder(position);
        if (newFolder) {
            DBusUtils.RemoteFileOperations.MoveURIsRemote(newFolderFileItems, newFolder);
        }
    }
};
