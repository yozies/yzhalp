import QtQuick
import "../js/WheelScroll.mjs" as WheelScroll

MouseArea {
    id: root
    required property Flickable flickable
    property real speed: 1
    readonly property bool scrolling: activity.running
    // Qt.styleHints is typed only as QObject in the installed QML metadata.
    // qmllint disable missing-property
    readonly property int scrollLines: Qt.styleHints.wheelScrollLines
    // qmllint enable missing-property

    // Wheel input is direct; pointer/touch dragging still belongs to Flickable.
    acceptedButtons: Qt.NoButton
    scrollGestureEnabled: true

    onWheel: function(event) {
        const movement = WheelScroll.delta(event.pixelDelta, event.angleDelta,
            root.scrollLines, root.speed, !!(event.modifiers & Qt.ShiftModifier));
        // Consume even at an edge so Flickable cannot reinterpret this event
        // as a velocity-limited animation. Do not round away subpixel movement.
        event.accepted = true;
        if (movement.x === 0 && movement.y === 0) return;
        const view = root.flickable;
        view.cancelFlick();
        if (movement.x !== 0)
            view.contentX = Math.max(view.originX, Math.min(view.originX + Math.max(0, view.contentWidth - view.width), view.contentX + movement.x));
        if (movement.y !== 0)
            view.contentY = Math.max(view.originY, Math.min(view.originY + Math.max(0, view.contentHeight - view.height), view.contentY + movement.y));
        activity.restart();
    }

    // This timer only keeps the scrollbars visible; it never delays input.
    Timer { id: activity; interval: 150 }
}
