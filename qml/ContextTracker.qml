import QtQuick
import Quickshell
import Quickshell.Wayland

Item {
    id: root
    property bool blocked: false
    property var context: ({ appId: "", title: "" })
    property var externalWindow: null

    function isSelf(toplevel) {
        return toplevel && toplevel.appId === Quickshell.appId && toplevel.title === "HALP";
    }

    function captureActive() {
        const active = ToplevelManager.activeToplevel;
        if (root.blocked || !active || root.isSelf(active)) return;
        root.externalWindow = active;
        root.captureProperties();
    }

    function captureProperties() {
        const active = root.externalWindow;
        if (root.blocked || !active || root.isSelf(active)) return;
        const next = { appId: String(active.appId || ""), title: String(active.title || "") };
        if (next.appId !== root.context.appId || next.title !== root.context.title)
            root.context = next;
    }

    Component.onCompleted: captureActive()
    Connections {
        target: ToplevelManager
        function onActiveToplevelChanged() { root.captureActive(); }
    }
    Connections {
        target: root.externalWindow
        function onAppIdChanged() { root.captureProperties(); }
        function onTitleChanged() { root.captureProperties(); }
        function onClosed() { root.externalWindow = null; }
    }
}
