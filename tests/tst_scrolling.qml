import QtQuick
import QtQuick.Controls
import QtTest
import "qml" as Halp

Item {
    id: root
    width: 800
    height: 600

    Component { id: imageComponent; Halp.ImageSheet { source: Qt.resolvedUrl("reference.svg") } }
    Component { id: pdfComponent; Halp.PdfSheet { source: Qt.resolvedUrl("reference.pdf") } }

    TestCase {
        id: testCase
        name: "DocumentWheelInput"
        when: windowShown

        function viewers() {
            return [{ tag: "image", component: imageComponent }, { tag: "pdf", component: pdfComponent }];
        }

        function createViewer(data) {
            const viewer = createTemporaryObject(data.component, root, { width: 620, height: 260 });
            verify(viewer !== null);
            tryCompare(viewer, "ready", true, 5000);
            viewer.zoomBy(4);
            wait(30);
            viewer.goTop();
            wait(30);
            return viewer;
        }

        function wheel(viewer, dx, dy, modifiers) {
            mouseWheel(viewer, 80, 80, dx, dy, Qt.NoButton, modifiers || Qt.NoModifier, 0);
        }

        function viewport(viewer) {
            return viewer.children.find(item => typeof item.contentY === "number");
        }

        function test_high_resolution_distance_data() { return viewers(); }
        function test_high_resolution_distance(data) {
            const viewer = createViewer(data);
            wheel(viewer, 0, -120);
            wait(450);
            const coarse = viewer.scrollY;
            verify(coarse > 0);
            viewer.goTop();
            wait(30);
            // The same total movement delivered as high-resolution wheel packets.
            for (let i = 0; i < 120; i++) wheel(viewer, 0, -1);
            wait(450);
            console.log(data.tag + ": one detent=" + coarse + ", 120 fine packets=" + viewer.scrollY);
            fuzzyCompare(viewer.scrollY, coarse, 0.5, "High-resolution packet size must not change the scroll distance");
        }

        function test_fast_wheel_burst_data() { return viewers(); }
        function test_fast_wheel_burst(data) {
            const viewer = createViewer(data);
            // A gesture scroller can emit a burst within a single render frame.
            for (let i = 0; i < 20; i++) wheel(viewer, 0, -120);
            const expected = 20 * Qt.styleHints.wheelScrollLines * 24;
            fuzzyCompare(viewer.scrollY, expected, 0.5, "Wheel distance must apply immediately, without a velocity cap");
            wait(300);
            fuzzyCompare(viewer.scrollY, expected, 0.5, "HALP must not add momentum after the input stops");
            wheel(viewer, 0, 120);
            fuzzyCompare(viewer.scrollY, expected - Qt.styleHints.wheelScrollLines * 24, 0.5, "Direction changes must be immediate");
        }

        function test_horizontal_and_diagonal_data() { return viewers(); }
        function test_horizontal_and_diagonal(data) {
            const viewer = createViewer(data);
            const view = viewport(viewer);
            const distance = Qt.styleHints.wheelScrollLines * 24;
            wheel(viewer, -120, -120);
            fuzzyCompare(view.contentX - view.originX, distance, 0.5);
            fuzzyCompare(viewer.scrollY, distance, 0.5);
            wheel(viewer, 0, -120, Qt.ShiftModifier);
            fuzzyCompare(view.contentX - view.originX, distance * 2, 0.5);
            fuzzyCompare(viewer.scrollY, distance, 0.5);
            wheel(viewer, -120, 0);
            fuzzyCompare(view.contentX - view.originX, distance * 3, 0.5);
        }

        function test_speed_and_large_events_data() { return viewers(); }
        function test_speed_and_large_events(data) {
            const viewer = createViewer(data);
            const distance = Qt.styleHints.wheelScrollLines * 24;
            wheel(viewer, 0, -1200);
            fuzzyCompare(viewer.scrollY, distance * 10, 0.5, "A large wheel delta must not be capped");
            viewer.goTop();
            viewer.scrollSpeed = 2;
            wheel(viewer, 0, -120);
            fuzzyCompare(viewer.scrollY, distance * 2, 0.5);
            viewer.scrollSpeed = 0.5;
            wheel(viewer, 0, -120);
            fuzzyCompare(viewer.scrollY, distance * 2.5, 0.5);
        }

        function test_bounds_data() { return viewers(); }
        function test_bounds(data) {
            const viewer = createViewer(data);
            wheel(viewer, 0, 12000);
            fuzzyCompare(viewer.scrollY, 0, 0.5);
            // Variable-height ListView rows update their origin as delegates
            // are recycled. Settle at the real boundary before testing it.
            tryVerify(function() {
                viewer.goBottom();
                return viewport(viewer).atYEnd;
            });
            const bottom = viewer.scrollY;
            wheel(viewer, 0, -12000);
            fuzzyCompare(viewer.scrollY, bottom, 0.5);
            wheel(viewer, 0, 120);
            fuzzyCompare(viewer.scrollY, bottom - Qt.styleHints.wheelScrollLines * 24, 0.5);
        }

        function test_scrollbar_feedback_data() { return viewers(); }
        function test_scrollbar_feedback(data) {
            const viewer = createViewer(data);
            const bar = viewport(viewer).ScrollBar.vertical;
            wheel(viewer, 0, -120);
            compare(bar.active, true, "Direct scrolling must still reveal the scrollbar");
            tryCompare(bar, "active", false, 1000);
        }

        function test_mouse_drag_still_works_data() { return viewers(); }
        function test_mouse_drag_still_works(data) {
            const viewer = createViewer(data);
            mouseDrag(viewer, 120, 180, 0, -100, Qt.LeftButton, Qt.NoModifier, 0);
            verify(viewer.scrollY > 20, "Wheel handling must not steal pointer dragging");
            viewport(viewer).cancelFlick();
        }
    }
}
