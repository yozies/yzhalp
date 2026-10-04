import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../js/Preferences.mjs" as Preferences

ScrollView {
    id: root
    required property var theme
    required property var values
    property var monitorNames: []
    property var draft: ({})
    signal previewRequested(var values)
    signal saveRequested(var values)
    signal placementRequested(var values)
    signal cancelRequested()

    Component.onCompleted: draft = Object.assign({}, values)
    function update(key, value) {
        const next = Object.assign({}, root.draft);
        next[key] = value;
        root.draft = next;
        root.previewRequested(next);
    }
    clip: true
    padding: 8
    background: Rectangle { color: root.theme.background; radius: root.theme.radius }
    contentWidth: availableWidth

    ColumnLayout {
        width: root.availableWidth
        spacing: 8
        Label { text: "HALP settings"; font.bold: true }
        Label { text: "Reference folder" }
        TextField {
            Layout.fillWidth: true
            text: root.draft.packsPath || ""
            selectByMouse: true
            onTextEdited: root.update("packsPath", text)
        }
        Label { text: "Scroll speed: " + Math.round((root.draft.scrollSpeed || 1) * 100) + "%" }
        Slider {
            Layout.fillWidth: true
            from: 0.25; to: 4; stepSize: 0.25; value: root.draft.scrollSpeed || 1
            onMoved: root.update("scrollSpeed", value)
        }
        Label {
            Layout.fillWidth: true
            text: "100% follows system wheel settings, with direct high-resolution scrolling."
            wrapMode: Text.WordWrap
        }
        HalpButton { theme: root.theme; text: "Reset scroll speed to 100%"; onClicked: root.update("scrollSpeed", 1) }
        Label { text: "Document opacity: " + Math.round((root.draft.normalOpacity || 1) * 100) + "%" }
        Slider {
            Layout.fillWidth: true
            from: 0.15; to: 1; value: root.draft.normalOpacity || 1
            onMoved: root.update("normalOpacity", value)
        }
        CheckBox {
            text: "Fade artwork on hover"
            checked: root.draft.hoverFade === true
            onToggled: root.update("hoverFade", checked)
        }
        Slider {
            Layout.fillWidth: true
            from: 0.05; to: 1; value: root.draft.hoverOpacity || 0.35
            enabled: root.draft.hoverFade === true
            onMoved: root.update("hoverOpacity", value)
        }
        CheckBox {
            text: "Show context and filename diagnostics"
            checked: root.draft.debug === true
            onToggled: root.update("debug", checked)
        }
        Label { text: "Floating placement"; font.bold: true }
        Label {
            Layout.fillWidth: true
            text: "Use Super+T to float HALP. Tiled geometry follows Hyprland."
            wrapMode: Text.WordWrap
        }
        ComboBox {
            Layout.fillWidth: true
            model: ["Current monitor"].concat(root.monitorNames)
            currentIndex: Math.max(0, root.monitorNames.indexOf(root.draft.monitor) + 1)
            onActivated: root.update("monitor", currentIndex === 0 ? "" : root.monitorNames[currentIndex - 1])
        }
        ComboBox {
            Layout.fillWidth: true
            model: Preferences.anchors
            currentIndex: Math.max(0, Preferences.anchors.indexOf(root.draft.anchor))
            onActivated: root.update("anchor", currentText)
        }
        GridLayout {
            columns: 2
            Layout.fillWidth: true
            Label { text: "Width" }
            SpinBox { from: 260; to: 7680; stepSize: 20; editable: true; value: root.draft.floatingWidth || 800; onValueModified: root.update("floatingWidth", value) }
            Label { text: "Height" }
            SpinBox { from: 180; to: 4320; stepSize: 20; editable: true; value: root.draft.floatingHeight || 700; onValueModified: root.update("floatingHeight", value) }
            Label { text: "X offset" }
            SpinBox { from: -7680; to: 7680; editable: true; value: root.draft.offsetX || 0; onValueModified: root.update("offsetX", value) }
            Label { text: "Y offset" }
            SpinBox { from: -4320; to: 4320; editable: true; value: root.draft.offsetY || 0; onValueModified: root.update("offsetY", value) }
        }
        HalpButton { theme: root.theme; text: "Apply floating placement"; onClicked: root.placementRequested(root.draft) }
        RowLayout {
            HalpButton { theme: root.theme; text: "Save"; onClicked: root.saveRequested(root.draft) }
            HalpButton { theme: root.theme; text: "Cancel"; onClicked: root.cancelRequested() }
        }
        Label {
            Layout.fillWidth: true
            text: "Preferences are saved in Omarchy's plugin entry. The host may reload the panel after saving; summon HALP again if needed."
            wrapMode: Text.WordWrap
            opacity: 0.7
        }
    }
}
