import { mkdtemp, writeFile, copyFile, cp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { fileURLToPath } from "node:url";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { samplePdf } from "../tests/fixtures.mjs";

const root = fileURLToPath(new URL("..", import.meta.url));
const directory = await mkdtemp(path.join(tmpdir(), "halp-scroll-"));
try {
    await cp(path.join(root, "qml"), path.join(directory, "qml"), { recursive: true });
    await cp(path.join(root, "js"), path.join(directory, "js"), { recursive: true });
    await copyFile(path.join(root, "tests/tst_scrolling.qml"), path.join(directory, "tst_scrolling.qml"));
    await copyFile(path.join(root, "examples/halp-guide/@any--HALP guide.svg"), path.join(directory, "reference.svg"));
    await writeFile(path.join(directory, "reference.pdf"), samplePdf());
    const result = spawnSync("/usr/lib/qt6/bin/qmltestrunner", ["-input", directory, "-o", "-,txt"], {
        encoding: "utf8", timeout: 60000,
        env: { ...process.env, QT_QPA_PLATFORM: "offscreen", QT_QUICK_BACKEND: "software", QTEST_MOUSEEVENT_DELAY: "0" }
    });
    console.log((result.stdout || "") + (result.stderr || ""));
    if (result.error) throw result.error;
    process.exitCode = result.status;
} finally { await rm(directory, { recursive: true, force: true }); }
