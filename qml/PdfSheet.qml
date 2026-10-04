pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Pdf
import "../js/RasterSize.mjs" as RasterSize

Item {
    id: root
    required property url source
    property real scrollSpeed: 1
    property bool fitWidth: true
    property real manualScale: 1
    property bool rendered: false
    property bool passwordNeeded: false
    readonly property real scaleFactor: fitWidth ? Math.max(1, width - 16) / Math.max(1, pdfDocument.maxPageWidth) : manualScale
    readonly property bool ready: pdfDocument.status === PdfDocument.Ready
    readonly property bool loading: pdfDocument.status === PdfDocument.Loading && !passwordNeeded
    readonly property string error: passwordNeeded ? "This PDF requires a password. Export an unlocked reference copy to display it here."
        : pdfDocument.status === PdfDocument.Error ? pdfDocument.error : ""
    readonly property int pageCount: pdfDocument.pageCount
    readonly property int currentPage: Math.max(0, pages.indexAt(pages.contentX + pages.width / 2, pages.contentY + pages.height / 2))
    readonly property string positionLabel: ready ? (currentPage + 1) + " / " + pageCount : ""
    readonly property real scrollY: pages.contentY - pages.originY

    function fitToWidth() { root.fitWidth = true; root.goTop(); }
    function zoomBy(factor) {
        const page = root.currentPage;
        root.manualScale = Math.max(0.05, Math.min(10, root.scaleFactor * factor));
        root.fitWidth = false;
        Qt.callLater(function() { pages.positionViewAtIndex(page, ListView.Beginning); });
    }
    function scrollBy(dx, dy) {
        pages.contentX = Math.max(0, Math.min(Math.max(0, pages.contentWidth - pages.width), pages.contentX + dx));
        pages.contentY = Math.max(pages.originY, Math.min(pages.originY + Math.max(0, pages.contentHeight - pages.height), pages.contentY + dy));
    }
    function goTop() { pages.positionViewAtBeginning(); pages.contentX = 0; }
    function goBottom() { pages.positionViewAtEnd(); }

    PdfDocument {
        id: pdfDocument
        source: root.source
        onPasswordRequired: root.passwordNeeded = true
    }
    ListView {
        id: pages
        anchors.fill: parent
        clip: true
        spacing: 8
        model: root.ready ? pdfDocument.pageCount : 0
        reuseItems: true
        cacheBuffer: height
        contentWidth: Math.max(width, pdfDocument.maxPageWidth * root.scaleFactor + 16)
        flickableDirection: Flickable.AutoFlickIfNeeded
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {
            id: verticalBar
            active: wheelArea.scrolling || pages.moving || hovered || pressed
        }
        ScrollBar.horizontal: ScrollBar {
            id: horizontalBar
            active: wheelArea.scrolling || pages.moving || hovered || pressed
        }
        delegate: Item {
            id: page
            required property int index
            readonly property size pointSize: pdfDocument.pagePointSize(index)
            width: pages.contentWidth
            height: pointSize.height * root.scaleFactor
            Rectangle {
                anchors.centerIn: parent
                width: page.pointSize.width * root.scaleFactor
                height: parent.height
                color: "white"
                PdfPageImage {
                    id: image
                    anchors.fill: parent
                    document: pdfDocument
                    currentFrame: page.index
                    asynchronous: true
                    retainWhileLoading: true
                    fillMode: Image.PreserveAspectFit
                    readonly property var rasterSize: RasterSize.renderSize(width, height, Screen.devicePixelRatio, false)
                    sourceSize: Qt.size(rasterSize.width, rasterSize.height)
                    onStatusChanged: if (status === Image.Ready) root.rendered = true
                }
            }
        }
    }
    NativeWheelArea {
        id: wheelArea
        anchors.fill: pages
        anchors.rightMargin: verticalBar.width
        anchors.bottomMargin: horizontalBar.height
        flickable: pages
        speed: root.scrollSpeed
    }
}
