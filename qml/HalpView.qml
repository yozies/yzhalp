pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

FocusScope {
    id: root
    required property var theme
    property var sheet: null
    property var matches: []
    property var context: ({ appId: "", title: "" })
    required property var preferences
    required property var appearance
    property string packDirectory: ""
    property bool indexReady: false
    property var errors: []
    property var monitorNames: []
    property bool settingsOpen: false
    property bool filterOpen: false
    property bool debugOpen: appearance.debug
    property string message: ""
    property bool awaitingG: false
    readonly property string sourceKey: sheet ? sheet.id + ":" + sheet.revision : ""
    readonly property var filteredMatches: matches.filter(item => (item.label + " " + item.id).toLowerCase().includes(filter.text.toLowerCase()))
    readonly property var viewer: documentLoader.item

    signal hideRequested()
    signal sheetRequested(string id)
    signal cycleRequested(int delta)
    signal settingsPreview(var values)
    signal settingsSave(var values)
    signal placementRequested(var values)

    focus: true
    function reloadDocument() { documentLoader.active = false; loadTimer.restart(); }
    onSourceKeyChanged: { reloadDocument(); filter.text = ""; }
    function viewerStatus() {
        return { kind: root.sheet ? root.sheet.kind : "", ready: !!root.viewer && root.viewer.ready,
            rendered: !!root.viewer && root.viewer.rendered,
            error: root.viewer ? root.viewer.error : "", zoom: root.viewer ? root.viewer.scaleFactor : 0,
            scrollY: root.viewer ? root.viewer.scrollY : 0,
            scrollSpeed: root.viewer ? root.viewer.scrollSpeed : 1,
            pageCount: root.viewer && root.sheet.kind === "pdf" ? root.viewer.pageCount : 0 };
    }
    function navigate(action) {
        if (!root.viewer) return;
        switch (action) {
        case "down": root.viewer.scrollBy(0, 48); break;
        case "up": root.viewer.scrollBy(0, -48); break;
        case "half-down": root.viewer.scrollBy(0, documentLoader.height / 2); break;
        case "half-up": root.viewer.scrollBy(0, -documentLoader.height / 2); break;
        case "left": root.viewer.scrollBy(-48, 0); break;
        case "right": root.viewer.scrollBy(48, 0); break;
        case "top": root.viewer.goTop(); break;
        case "bottom": root.viewer.goBottom(); break;
        case "zoom-in": root.viewer.zoomBy(1.2); break;
        case "zoom-out": root.viewer.zoomBy(1 / 1.2); break;
        case "fit": root.viewer.fitToWidth(); break;
        }
    }
    function closeSettings() {
        root.settingsOpen = false;
        root.settingsPreview(null);
        root.forceActiveFocus();
    }

    Timer {
        id: loadTimer
        interval: 0
        onTriggered: {
            if (!root.sheet) return;
            documentLoader.sourceComponent = root.sheet.kind === "pdf" ? pdfComponent : imageComponent;
            documentLoader.active = true;
        }
    }
    Timer { id: gTimer; interval: 600; onTriggered: root.awaitingG = false }
    Component {
        id: imageComponent
        ImageSheet {
            source: root.sheet ? root.sheet.url : ""
            scrollSpeed: root.appearance.scrollSpeed || 1
        }
    }
    Component {
        id: pdfComponent
        PdfSheet {
            source: root.sheet ? root.sheet.url : ""
            scrollSpeed: root.appearance.scrollSpeed || 1
        }
    }

    Keys.priority: Keys.AfterItem
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
            if (root.settingsOpen) root.closeSettings();
            else if (root.filterOpen) { root.filterOpen = false; filter.text = ""; root.forceActiveFocus(); }
            else menu.close();
            event.accepted = true;
            return;
        }
        if (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_W) {
            root.hideRequested(); event.accepted = true; return;
        }
        if (root.settingsOpen || filter.activeFocus) return;
        let action = "";
        if (event.modifiers & Qt.ControlModifier) {
            if (event.key === Qt.Key_D) action = "half-down";
            else if (event.key === Qt.Key_U) action = "half-up";
            else if (event.key === Qt.Key_F) { root.filterOpen = true; filter.forceActiveFocus(); event.accepted = true; }
        } else {
            if (event.key === Qt.Key_J || event.key === Qt.Key_Down) action = "down";
            else if (event.key === Qt.Key_K || event.key === Qt.Key_Up) action = "up";
            else if (event.key === Qt.Key_Left) action = "left";
            else if (event.key === Qt.Key_Right) action = "right";
            else if (event.key === Qt.Key_PageDown || event.key === Qt.Key_Space) action = "half-down";
            else if (event.key === Qt.Key_PageUp) action = "half-up";
            else if (event.key === Qt.Key_Home) action = "top";
            else if (event.key === Qt.Key_End || event.text === "G") action = "bottom";
            else if (event.text === "g") {
                if (root.awaitingG) { action = "top"; root.awaitingG = false; gTimer.stop(); }
                else { root.awaitingG = true; gTimer.restart(); }
                event.accepted = true;
            } else if (event.text === "+" || event.text === "=") action = "zoom-in";
            else if (event.text === "-") action = "zoom-out";
            else if (event.text === "0") action = "fit";
            else if (event.text === "[") { root.cycleRequested(-1); event.accepted = true; }
            else if (event.text === "]") { root.cycleRequested(1); event.accepted = true; }
            else if (/^[1-9]$/.test(event.text)) {
                const index = Number(event.text) - 1;
                if (root.matches[index]) root.sheetRequested(root.matches[index].id);
                event.accepted = true;
            } else if (event.text === "/") { root.filterOpen = true; filter.forceActiveFocus(); event.accepted = true; }
        }
        if (action) { root.navigate(action); event.accepted = true; }
        if (event.text !== "g") root.awaitingG = false;
    }

    Pane {
        anchors.fill: parent
        padding: 6
        background: Item {}
        font.family: root.theme.fontFamily
        font.pixelSize: root.theme.fontSize
        palette.window: root.theme.background
        palette.base: root.theme.background
        palette.button: root.theme.background
        palette.text: root.theme.foreground
        palette.windowText: root.theme.foreground
        palette.buttonText: root.theme.foreground
        palette.highlight: root.theme.accent

        ColumnLayout {
            anchors.fill: parent
            spacing: 4
            Flow {
                Layout.fillWidth: true
                Layout.preferredHeight: childrenRect.height
                spacing: 4
                HalpButton { theme: root.theme; text: "−"; enabled: !!root.viewer; onClicked: root.navigate("zoom-out") }
                HalpButton { theme: root.theme; text: root.viewer ? Math.round(root.viewer.scaleFactor * 100) + "%" : "—"; onClicked: root.navigate("fit") }
                HalpButton { theme: root.theme; text: "+"; enabled: !!root.viewer; onClicked: root.navigate("zoom-in") }
                HalpButton { theme: root.theme; text: "Fit"; onClicked: root.navigate("fit") }
                HalpButton {
                    id: menuButton
                    theme: root.theme; text: "⋯"
                    onClicked: menu.popup(menuButton, 0, menuButton.height)
                    Menu {
                        id: menu
                        MenuItem { text: "Previous sheet    ["; onTriggered: root.cycleRequested(-1) }
                        MenuItem { text: "Next sheet        ]"; onTriggered: root.cycleRequested(1) }
                        MenuItem { text: "Filter sheets     /"; onTriggered: { root.filterOpen = true; filter.forceActiveFocus(); } }
                        MenuItem { text: "Reload document"; onTriggered: root.reloadDocument() }
                        MenuItem { text: "Context / diagnostics"; checkable: true; checked: root.debugOpen; onTriggered: root.debugOpen = checked }
                        MenuItem { text: "Settings"; onTriggered: root.settingsOpen = true }
                    }
                }
                HalpButton { theme: root.theme; text: "Hide"; onClicked: root.hideRequested() }
                Label { text: root.viewer ? root.viewer.positionLabel : ""; padding: 6 }
            }
            TextField {
                id: filter
                Layout.fillWidth: true
                visible: root.filterOpen
                placeholderText: "Filter matching filenames…"
                selectByMouse: true
                onAccepted: {
                    if (root.filteredMatches.length) root.sheetRequested(root.filteredMatches[0].id);
                    root.filterOpen = false;
                    text = "";
                    root.forceActiveFocus();
                }
            }
            Flickable {
                Layout.fillWidth: true
                Layout.preferredHeight: tabs.implicitHeight
                contentWidth: tabs.implicitWidth
                contentHeight: tabs.implicitHeight
                clip: true
                visible: root.matches.length > 1 || root.filterOpen
                flickableDirection: Flickable.HorizontalFlick
                boundsBehavior: Flickable.StopAtBounds
                Row {
                    id: tabs
                    spacing: 4
                    Repeater {
                        model: root.filteredMatches
                        delegate: HalpButton {
                            required property var modelData
                            theme: root.theme
                            text: modelData.label
                            checked: root.sheet && modelData.id === root.sheet.id
                            onClicked: { root.sheetRequested(modelData.id); root.forceActiveFocus(); }
                            ToolTip.visible: hovered
                            ToolTip.text: modelData.id
                        }
                    }
                }
            }
            Label {
                Layout.fillWidth: true
                visible: root.message !== ""
                text: root.message
                textFormat: Text.PlainText
                wrapMode: Text.WordWrap
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: debugText.implicitHeight + 12
                visible: root.debugOpen
                color: root.theme.background
                Text {
                    id: debugText
                    anchors.fill: parent
                    anchors.margins: 6
                    color: root.theme.foreground
                    font.family: root.theme.fontFamily
                    font.pixelSize: root.theme.fontSize
                    textFormat: Text.PlainText
                    wrapMode: Text.WrapAnywhere
                    text: "appId: " + root.context.appId + "\ntitle: " + root.context.title
                        + "\nselected: " + (root.sheet ? root.sheet.id : "—")
                        + "\nmatches: " + root.matches.map(item => item.id).join(", ")
                        + (root.errors.length ? "\n" + root.errors.join("\n") : "")
                }
            }
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: !root.settingsOpen
                HoverHandler { id: artworkHover }
                Loader {
                    id: documentLoader
                    anchors.fill: parent
                    active: false
                    opacity: root.appearance.hoverFade && artworkHover.hovered ? root.appearance.hoverOpacity : root.appearance.normalOpacity
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                }
                Label {
                    anchors.centerIn: parent
                    width: Math.max(0, parent.width - 24)
                    padding: 12
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WrapAnywhere
                    textFormat: Text.PlainText
                    visible: !root.sheet || !root.viewer || root.viewer.loading || root.viewer.error !== ""
                    text: !root.indexReady ? "Indexing reference files…"
                        : !root.sheet ? "No reference matches this window.\n\nAdd your images or PDFs to\n" + root.packDirectory
                            + "\n\nExample: @any--My reference.pdf"
                            + (root.errors.length ? "\n\n" + root.errors.join("\n") : "")
                        : root.viewer && root.viewer.error ? root.viewer.error : "Loading…"
                    background: Rectangle { color: root.theme.background; radius: root.theme.radius }
                }
            }
            Loader {
                Layout.fillWidth: true
                Layout.fillHeight: true
                active: root.settingsOpen
                visible: root.settingsOpen
                sourceComponent: Component {
                    SettingsPane {
                        theme: root.theme
                        values: root.preferences
                        monitorNames: root.monitorNames
                        onPreviewRequested: function(values) { root.settingsPreview(values); }
                        onSaveRequested: function(values) { root.settingsSave(values); root.closeSettings(); }
                        onCancelRequested: root.closeSettings()
                        onPlacementRequested: function(values) { root.placementRequested(values); }
                    }
                }
            }
        }
    }
}
