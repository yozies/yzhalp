import QtQuick
import QtQuick.Controls

AbstractButton {
    id: root
    required property var theme
    implicitWidth: label.implicitWidth + 16
    implicitHeight: Math.max(26, label.implicitHeight + 10)
    hoverEnabled: true
    focusPolicy: Qt.TabFocus
    contentItem: Text {
        id: label
        text: root.text
        textFormat: Text.PlainText
        color: root.checked || root.hovered ? root.theme.accent : root.theme.foreground
        font.family: root.theme.fontFamily
        font.pixelSize: root.theme.fontSize
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        opacity: root.enabled ? 1 : 0.4
    }
    background: Rectangle {
        radius: Math.min(root.theme.radius, 5)
        color: root.down ? Qt.alpha(root.theme.accent, 0.18) : Qt.alpha(root.theme.background, 0.92)
        border.width: 1
        border.color: root.checked || root.activeFocus ? root.theme.accent : Qt.alpha(root.theme.foreground, 0.2)
    }
}
