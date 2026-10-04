import { mkdtemp, writeFile, copyFile, cp } from "node:fs/promises";
import { tmpdir } from "node:os";
import { fileURLToPath, pathToFileURL } from "node:url";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { samplePdf } from "../tests/fixtures.mjs";

const root = fileURLToPath(new URL("..", import.meta.url));
const directory = await mkdtemp(path.join(tmpdir(), "halp-render-"));
const guide = path.join(root, "examples/halp-guide/@any--HALP guide.svg");
const cases = [];
for (const extension of ["svg", "png", "jpg", "webp", "pdf"]) {
    const target = path.join(directory, `@any--Reference # + 100%.${extension}`);
    if (extension === "pdf") await writeFile(target, samplePdf());
    else if (extension === "svg") await copyFile(guide, target);
    else {
        const result = spawnSync("magick", [guide, "-resize", "780x1120", target], { encoding: "utf8" });
        if (result.error || result.status !== 0) throw result.error || new Error(result.stderr);
    }
    cases.push({ id: extension, label: extension, url: pathToFileURL(target).href,
        kind: extension === "pdf" ? "pdf" : "image", revision: "1" });
}
for (const extension of ["png", "pdf"]) {
    const target = path.join(directory, "broken." + extension);
    await writeFile(target, "Not a valid document");
    cases.push({ id: "broken-" + extension, label: "Broken file", url: pathToFileURL(target).href,
        kind: extension === "pdf" ? "pdf" : "image", revision: "1", broken: true });
}
cases.push({ ...cases[0], id: "narrow", narrow: true });
cases.push({ ...cases[0], id: "large", large: true });
cases.push({ ...cases[4], id: "large-pdf", large: true });
cases.push({ ...cases[0], id: "settings", settings: true });
await copyFile(path.join(root, "tests/RenderSmoke.qml"), path.join(directory, "shell.qml"));
await cp(path.join(root, "qml"), path.join(directory, "qml"), { recursive: true });
await cp(path.join(root, "js"), path.join(directory, "js"), { recursive: true });
const result = spawnSync("quickshell", ["--no-color", "-p", path.join(directory, "shell.qml")], {
    encoding: "utf8", timeout: 90000,
    env: { ...process.env, QT_QPA_PLATFORM: "offscreen", QT_QUICK_BACKEND: "software", QT_SCALE_FACTOR: "2",
        HALP_SMOKE_CASES: JSON.stringify(cases), HALP_SMOKE_OUTPUT: directory }
});
const log = (result.stdout || "") + (result.stderr || "");
console.log(log);
console.log("Render captures: " + directory);
// The deliberately corrupt image is expected to generate a Qt image decoder warning.
const unexpected = /ReferenceError|TypeError|Binding loop|Cannot assign|is not installed|failed to load|not ready|QML Error|allocation limit/i.test(log);
if (result.error || result.status !== 0 || !log.includes("HALP_SMOKE_PASS") || unexpected) process.exitCode = 1;
