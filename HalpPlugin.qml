import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons
import "qml"
import "js/Matcher.mjs" as Matcher
import "js/Preferences.mjs" as Preferences

Item {
    id: root
    property var shell: null
    property var manifest: null
    readonly property string pluginId: "yzjm.halp"
    readonly property bool opened: window.visible
    property bool activating: false
    property int activationAttempts: 0
    property var matches: []
    property string selection: ""
    property string contextKey: ""
    property var preview: null
    readonly property var selectedSheet: matches.find(item => item.id === selection) || null
    readonly property var appearance: preview ? Preferences.normalize(preview, settings.home) : settings.values
    readonly property var theme: ({
        foreground: Color.foreground, background: Color.background, accent: Color.accent,
        muted: Color.muted, fontFamily: Style.fontFamily, fontSize: Style.fontToken("body", Style.fontPx(1)),
        radius: Style.cornerRadius
    })

    function updateMatches() {
        const key = JSON.stringify(contextTracker.context);
        const next = Matcher.matchingSheets(packs.entries, contextTracker.context);
        const selected = Matcher.selectedId(next, root.selection, key !== root.contextKey);
        root.contextKey = key;
        root.matches = next;
        root.selection = selected;
    }

    function selectSheet(id) {
        if (root.matches.some(item => item.id === id)) root.selection = id;
    }

    function cycleSheet(delta) {
        if (!root.matches.length) return;
        const current = root.matches.findIndex(item => item.id === root.selection);
        root.selection = root.matches[(current + delta + root.matches.length) % root.matches.length].id;
    }

    function open(payloadJson) {
        contextTracker.captureActive();
        root.activationAttempts = 0;
        root.activating = true;
        window.minimized = false;
        window.visible = true;
        activateTimer.restart();
        root.activateSelf();
        Qt.callLater(function() { view.forceActiveFocus(); });
    }

    function activateSelf() {
        if (!root.activating || !root.opened) return;
        const own = ToplevelManager.toplevels.values.find(item => contextTracker.isSelf(item));
        if (own) {
            own.activate();
            if (own.activated) { root.activating = false; activateTimer.stop(); }
        }
        if (++root.activationAttempts >= 20) {
            root.activating = false;
            activateTimer.stop();
        }
    }

    function close() {
        root.activating = false;
        activateTimer.stop();
        window.visible = false;
        root.preview = null;
    }

    function requestHide() {
        if (root.shell) root.shell.hide(root.pluginId);
        else root.close();
    }

    // A small diagnostic API also makes real host integration testable over IPC.
    function status() {
        return JSON.stringify({ opened: root.opened, context: contextTracker.context,
            matches: root.matches.map(item => item.id), selected: root.selection,
            indexed: packs.entries.length, indexReady: packs.ready, packDirectory: packs.directory,
            revision: root.selectedSheet ? root.selectedSheet.revision : "",
            errors: packs.errors, settingsError: settings.error,
            viewer: view.viewerStatus() });
    }

    function navigate(action) { view.navigate(action); }

    function configure(payloadJson) {
        const values = JSON.parse(payloadJson);
        if (!values || typeof values !== "object" || Array.isArray(values)) return "Expected a settings object";
        settings.save(Object.assign({}, settings.values, values));
        return "ok";
    }

    function placeWindow(values) {
        if (placement.running) return;
        placement.command = ["node", decodeURIComponent(Qt.resolvedUrl("tools/place-window.mjs").toString().replace("file://", "")),
            String(Quickshell.processId), JSON.stringify(values)];
        placement.running = true;
    }

    SettingsStore { id: settings; shell: root.shell }
    ContextTracker {
        id: contextTracker
        blocked: root.activating
        onContextChanged: root.updateMatches()
    }
    PackIndex {
        id: packs
        directory: Quickshell.env("HALP_PACKS_PATH") || settings.values.packsPath
        onEntriesChanged: root.updateMatches()
    }
    Timer { id: activateTimer; interval: 50; repeat: true; onTriggered: root.activateSelf() }
    Process {
        id: placement
        stdout: StdioCollector { id: placementOutput }
        stderr: StdioCollector { id: placementError }
        // Quickshell's installed qmltypes omits the QProcess::ExitStatus enum.
        // qmllint disable signal-handler-parameters
        onExited: function(code) { view.message = code === 0 ? placementOutput.text : placementError.text; }
        // qmllint enable signal-handler-parameters
    }
    FloatingWindow {
        id: window
        title: "HALP"
        visible: false
        color: "transparent"
        implicitWidth: settings.values.floatingWidth
        implicitHeight: settings.values.floatingHeight
        minimumSize: Qt.size(260, 180)
        onClosed: root.requestHide()

        HalpView {
            id: view
            anchors.fill: parent
            theme: root.theme
            sheet: root.selectedSheet
            matches: root.matches
            context: contextTracker.context
            preferences: settings.values
            appearance: root.appearance
            packDirectory: packs.directory
            indexReady: packs.ready
            errors: packs.errors.concat(settings.error ? [settings.error] : [])
            monitorNames: Hyprland.monitors.values.map(item => item.name)
            onHideRequested: root.requestHide()
            onSheetRequested: function(id) { root.selectSheet(id); }
            onCycleRequested: function(delta) { root.cycleSheet(delta); }
            onSettingsPreview: function(values) { root.preview = values; }
            onSettingsSave: function(values) { root.preview = null; settings.save(values); }
            onPlacementRequested: function(values) { root.placeWindow(values); }
        }
    }
}
