import QtQuick
import Quickshell
import Quickshell.Io
import "../js/Preferences.mjs" as Preferences

Item {
    id: root
    property var shell: null
    property string pluginId: "yzjm.halp"
    property string home: Quickshell.env("HOME")
    property string path: home + "/.config/omarchy/shell.json"
    property var entry: ({})
    property var values: Preferences.normalize(entry, home)
    property string error: ""

    function load(text) {
        try {
            const config = JSON.parse(text);
            root.entry = (config.plugins || []).find(item => item.id === root.pluginId) || {};
            root.error = "";
        } catch (problem) { root.error = "Could not read HALP settings: " + problem; }
    }

    function save(settings) {
        if (!root.shell || typeof root.shell.updateEntryInline !== "function") {
            root.error = "Settings can be saved when HALP runs inside Omarchy Shell";
            return;
        }
        // Preserve future/unknown fields on this plugin's entry.
        root.shell.updateEntryInline(root.pluginId, Object.assign({}, root.entry,
            Preferences.normalize(settings, root.home)));
    }

    FileView {
        path: root.path
        watchChanges: true
        printErrors: false
        onLoaded: root.load(text())
        onFileChanged: reload()
    }
}
