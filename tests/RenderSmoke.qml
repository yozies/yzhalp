import QtQuick
import Quickshell
import "qml"
import "js/FilenameRules.mjs" as FileRules
import "js/Matcher.mjs" as Matcher
import "js/Preferences.mjs" as Preferences

ShellRoot {
    id: root
    property var cases: JSON.parse(Quickshell.env("HALP_SMOKE_CASES"))
    property int caseIndex: -1
    property int ticks: 0
    property int stage: 0
    property bool failed: false
    function fail(reason) { root.failed = true; console.error("HALP_SMOKE_FAIL " + reason); Qt.quit(); }
    function next() {
        root.caseIndex++;
        root.ticks = 0;
        root.stage = 0;
        if (root.caseIndex === root.cases.length) { console.log("HALP_SMOKE_PASS"); Qt.quit(); return; }
        view.sheet = root.cases[root.caseIndex];
        view.matches = [view.sheet];
        console.log("HALP_SMOKE_CASE " + view.sheet.id);
    }
    Component.onCompleted: {
        const indexed = FileRules.indexFiles([{ relativePath: "pack/@terminal~NVIM--Editor.pdf", path: "/packs/Editor.pdf", revision: "1" }]);
        const matches = Matcher.matchingSheets(indexed.entries, { appId: "foot", title: "notes - NVIM" });
        if (indexed.errors.length || matches.length !== 1 || Preferences.normalize({}, "/test").packsPath !== "/test/.config/halp/packs") {
            root.fail("Shared JavaScript modules failed inside Qt"); return;
        }
        next();
    }
    FloatingWindow {
        id: window
        title: "HALP render check"
        implicitWidth: 1840
        implicitHeight: 460
        visible: true
        HalpView {
            id: view
            width: sheet && sheet.large ? 1840 : sheet && sheet.narrow ? 280 : 620
            height: parent.height
            indexReady: true
            theme: ({ foreground: Qt.rgba(0.9, 0.94, 0.94, 1), background: Qt.rgba(0.06, 0.1, 0.12, 1),
                accent: Qt.rgba(0.5, 0.85, 0.76, 1), muted: "gray", fontFamily: "monospace", fontSize: 12, radius: 0 })
            preferences: ({ packsPath: "/test", normalOpacity: 1, hoverOpacity: 0.35, hoverFade: false, debug: false })
            appearance: preferences
        }
    }
    Timer {
        interval: 100
        repeat: true
        running: true
        onTriggered: {
            if (root.failed || root.caseIndex >= root.cases.length) return;
            if (++root.ticks > 120) { root.fail("timeout " + JSON.stringify(view.viewerStatus())); return; }
            const testcase = root.cases[root.caseIndex];
            const status = view.viewerStatus();
            if (testcase.broken) {
                if (status.error) root.next();
                return;
            }
            if (status.error) { root.fail(testcase.id + ": " + status.error); return; }
            if (!status.rendered) return;
            const expectedWidth = testcase.large ? 1840 : testcase.narrow ? 280 : 620;
            if (view.width !== expectedWidth) { root.fail("Viewport resize did not apply: " + view.width); return; }
            if (testcase.kind === "pdf" && status.pageCount !== 2) { root.fail("Expected two PDF pages"); return; }
            if (testcase.settings && root.stage === 0) { view.settingsOpen = true; root.stage = 3; return; }
            if (root.stage === 0) {
                root.stage = 1;
                view.navigate("bottom");
            } else if (root.stage === 1) {
                if (status.scrollY <= 0 && !testcase.narrow) { root.fail("Cannot scroll " + testcase.id); return; }
                view.navigate("top");
                view.navigate("zoom-in");
                root.stage = 2;
            } else if (root.stage === 2) {
                view.navigate("fit");
                root.stage = 3;
            } else if (root.stage === 3) {
                if (status.scrollY > 1) { root.fail("Fit did not return to top"); return; }
                root.stage = 4;
                view.grabToImage(function(result) {
                    result.saveToFile(Quickshell.env("HALP_SMOKE_OUTPUT") + "/" + testcase.id + ".png");
                    view.settingsOpen = false;
                    root.next();
                });
            }
        }
    }
}
