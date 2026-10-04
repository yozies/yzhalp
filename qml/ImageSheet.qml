import QtQuick
import QtQuick.Controls
import "../js/RasterSize.mjs" as RasterSize

Item {
    id: root
    required property url source
    property real scrollSpeed: 1
    property size intrinsicSize: Qt.size(0, 0)
    readonly property real intrinsicWidth: intrinsicSize.width
    readonly property real intrinsicHeight: intrinsicSize.height
    property bool fitWidth: true
    property real manualScale: 1
    readonly property real scaleFactor: fitWidth ? Math.max(1, width - 12) / Math.max(1, intrinsicWidth) : manualScale
    readonly property bool ready: image.status === Image.Ready
    readonly property bool rendered: ready
    readonly property bool loading: image.status === Image.Loading
    readonly property string error: image.status === Image.Error ? "This image could not be loaded. Check the file and its format." : ""
    readonly property string positionLabel: ""
    readonly property real scrollY: flick.contentY

    function fitToWidth() { root.fitWidth = true; root.goTop(); }
    function zoomBy(factor) {
        const previousScale = root.scaleFactor;
        const x = flick.contentX;
        const y = flick.contentY;
        root.manualScale = Math.max(0.05, Math.min(10, previousScale * factor));
        root.fitWidth = false;
        const ratio = root.manualScale / previousScale;
        Qt.callLater(function() {
            flick.contentX = (x + flick.width / 2) * ratio - flick.width / 2;
            flick.contentY = (y + flick.height / 2) * ratio - flick.height / 2;
            flick.returnToBounds();
        });
    }
    function scrollBy(dx, dy) {
        flick.contentX = Math.max(0, Math.min(Math.max(0, flick.contentWidth - flick.width), flick.contentX + dx));
        flick.contentY = Math.max(0, Math.min(Math.max(0, flick.contentHeight - flick.height), flick.contentY + dy));
    }
    function goTop() { flick.contentY = 0; flick.contentX = 0; }
    function goBottom() { flick.contentY = Math.max(0, flick.contentHeight - flick.height); }

    Flickable {
        id: flick
        anchors.fill: parent
        clip: true
        contentWidth: Math.max(width, image.width + 12)
        contentHeight: Math.max(height, image.height)
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {
            id: verticalBar
            active: wheelArea.scrolling || flick.moving || hovered || pressed
        }
        ScrollBar.horizontal: ScrollBar {
            id: horizontalBar
            active: wheelArea.scrolling || flick.moving || hovered || pressed
        }
        Image {
            id: image
            source: root.source
            asynchronous: true
            cache: false
            retainWhileLoading: true
            width: root.intrinsicWidth * root.scaleFactor
            height: root.intrinsicHeight * root.scaleFactor
            x: (flick.contentWidth - width) / 2
            fillMode: Image.PreserveAspectFit
            readonly property var rasterSize: RasterSize.renderSize(width, height, Screen.devicePixelRatio,
                root.source.toString().toLowerCase().endsWith(".svg"))
            sourceSize: root.intrinsicWidth > 0 ? Qt.size(rasterSize.width, rasterSize.height) : Qt.size(0, 0)
            onStatusChanged: {
                if (status === Image.Ready && root.intrinsicWidth === 0) {
                    root.intrinsicSize = Qt.size(implicitWidth, implicitHeight);
                }
            }
        }
    }
    NativeWheelArea {
        id: wheelArea
        anchors.fill: flick
        anchors.rightMargin: verticalBar.width
        anchors.bottomMargin: horizontalBar.height
        flickable: flick
        speed: root.scrollSpeed
    }
}
