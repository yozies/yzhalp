import QtQuick
import Quickshell.Io
import "../js/FilenameRules.mjs" as FileRules

Item {
    id: root
    required property string directory
    property var entries: []
    property var errors: []
    property bool ready: false
    property bool started: false

    function restart() {
        root.ready = false;
        root.entries = [];
        worker.running = false;
        restartTimer.restart();
    }

    onDirectoryChanged: if (started) restart()
    Component.onCompleted: { started = true; restart(); }

    Timer {
        id: restartTimer
        interval: 250
        onTriggered: {
            if (worker.running) { restart(); return; }
            worker.command = ["node", decodeURIComponent(Qt.resolvedUrl("../tools/watch-packs.mjs").toString().replace("file://", "")), root.directory];
            worker.running = true;
        }
    }
    Process {
        id: worker
        stdout: SplitParser {
            onRead: function(line) {
                try {
                    const snapshot = JSON.parse(line);
                    if (snapshot.root !== root.directory) return;
                    const result = FileRules.indexFiles(snapshot.files);
                    root.errors = snapshot.errors.concat(result.errors);
                    root.entries = result.entries;
                    root.ready = true;
                } catch (error) { root.errors = ["Could not read pack index: " + error]; }
            }
        }
        stderr: StdioCollector { id: workerError }
        // Quickshell's installed qmltypes omits the QProcess::ExitStatus enum.
        // qmllint disable signal-handler-parameters
        onExited: function(code) {
            if (code !== 0) root.errors = ["Pack watcher stopped: " + workerError.text];
            restartTimer.restart();
        }
        // qmllint enable signal-handler-parameters
    }
}
