import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    FloatingWindow {
        id: window
        title: "HALP test image"
        implicitWidth: 400
        implicitHeight: 240
        color: "#172c35"
        Text { anchors.centerIn: parent; color: "white"; text: window.title; font.pixelSize: 22 }
    }
    IpcHandler {
        target: "probe"
        function setTitle(value: string): void { window.title = value; }
    }
}
