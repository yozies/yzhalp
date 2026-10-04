// Explicit, live desktop check. Only HALP and an isolated probe window are moved.
import assert from "node:assert/strict";
import { mkdtemp, mkdir, copyFile, readFile, writeFile, rename, rm } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { spawn, execFileSync } from "node:child_process";
import { setTimeout as delay } from "node:timers/promises";
import { samplePdf } from "../tests/fixtures.mjs";
import { floatingRect, normalize } from "../js/Preferences.mjs";

const root = fileURLToPath(new URL("..", import.meta.url));
const ipc = (...args) => execFileSync("omarchy-shell", ["shell", ...args], { encoding: "utf8" }).trim();
const query = command => JSON.parse(execFileSync("hyprctl", ["-j", command], { encoding: "utf8" }));
const dispatch = code => {
    const output = execFileSync("hyprctl", ["dispatch", code], { encoding: "utf8" }).trim();
    assert.equal(output, "ok", output);
};
const status = () => JSON.parse(ipc("call", "yzjm.halp", "status", ""));
const halpClient = () => query("clients").find(window => window.title === "HALP" && window.class === "org.quickshell");
const selector = window => JSON.stringify("address:" + window.address);
const focus = window => dispatch(`hl.dsp.focus({ window = ${selector(window)} })`);
async function until(predicate, description) {
    for (let i = 0; i < 100; i++) { if (predicate()) return; await delay(80); }
    throw new Error("Timed out: " + description + "\n" + JSON.stringify(status()));
}

const initialWorkspace = query("activeworkspace");
const priorFocus = query("activewindow");
const restoreFocus = priorFocus.title !== "HALP" ? priorFocus : query("clients")
    .filter(window => window.title !== "HALP").sort((a, b) => a.focusHistoryID - b.focusHistoryID)[0];
const preferences = status();
const configPath = path.join(process.env.HOME, ".config/omarchy/shell.json");
const originalConfig = JSON.parse(await readFile(configPath, "utf8"));
const originalSettings = originalConfig.plugins.find(entry => entry.id === "yzjm.halp") || {};
const directory = await mkdtemp(path.join(preferences.packDirectory, "halp-check-"));
const prefix = path.basename(directory);
const probeApp = "org.yzjm.halp-probe";
const probePath = path.join(root, "tests/ContextProbe.qml");
let probe;
let originalHalp;
let probeLog = "";
let settingsTouched = false;

try {
    const imageName = probeApp + "--Image.svg";
    const pdfName = probeApp + "~PDF--PDF.pdf";
    const imagePath = path.join(directory, imageName);
    await copyFile(path.join(root, "examples/halp-guide/@any--HALP guide.svg"), imagePath);
    await writeFile(path.join(directory, pdfName), samplePdf());
    probe = spawn("quickshell", ["--no-color", "-p", probePath], { env: { ...process.env, QS_APP_ID: probeApp }, stdio: ["ignore", "pipe", "pipe"] });
    probe.stdout.on("data", value => { probeLog += value; });
    probe.stderr.on("data", value => { probeLog += value; });
    let probeWindow;
    await until(() => { probeWindow = query("clients").find(window => window.class === probeApp); return !!probeWindow; }, "probe window");
    focus(probeWindow);
    await until(() => status().context.appId === probeApp && status().selected === prefix + "/" + imageName, "external app matching");
    ipc("summon", "yzjm.halp", "{}");
    await until(() => status().opened && status().viewer.rendered && query("activewindow").title === "HALP", "HALP activation");
    originalHalp = halpClient();
    assert.equal(originalHalp.floating, false);
    assert.equal(status().context.appId, probeApp, "Self focus must not overwrite context");
    ipc("summon", "yzjm.halp", "{}");
    assert.equal(halpClient().address, originalHalp.address, "Summon must reuse the window");
    console.log("PASS: normal tiled client, context matching, self exclusion, repeat summon");

    const originalRevision = status().revision;
    const svg = await readFile(imagePath, "utf8");
    await writeFile(imagePath + ".tmp", svg.replace("HALP</text>", "LIVE</text>"));
    await rename(imagePath + ".tmp", imagePath);
    await until(() => status().revision !== originalRevision && status().viewer.rendered, "atomic image replacement");
    assert.equal(halpClient().address, originalHalp.address);
    const duplicate = path.join(directory, "nested");
    await mkdir(duplicate);
    await copyFile(imagePath, path.join(duplicate, imageName));
    await until(() => status().matches.includes(prefix + "/nested/" + imageName), "new nested file");
    assert.ok(status().matches.includes(prefix + "/" + imageName));
    console.log("PASS: live replacement and discovery, duplicate filenames, stable mapped window");

    execFileSync("quickshell", ["ipc", "-p", probePath, "call", "probe", "setTitle", "HALP test PDF"], { encoding: "utf8" });
    await until(() => status().selected === prefix + "/" + pdfName && status().viewer.rendered, "title-driven PDF selection");
    assert.equal(status().viewer.pageCount, 2);
    ipc("call", "yzjm.halp", "navigate", "bottom");
    await until(() => status().viewer.scrollY > 0, "PDF scroll");
    await rm(path.join(directory, pdfName));
    await until(() => status().selected !== prefix + "/" + pdfName && status().viewer.kind === "image" && status().viewer.rendered, "deleted PDF fallback");
    console.log("PASS: title changes, multi-page PDF, scrolling, deletion fallback");

    const workspace = "name:halp-check-" + process.pid;
    dispatch(`hl.dsp.window.move({ window = ${selector(originalHalp)}, workspace = ${JSON.stringify(workspace)}, follow = true })`);
    await until(() => query("activeworkspace").name === workspace.slice(5), "isolated workspace");
    assert.equal(query("activeworkspace").tiledLayout, "dwindle");
    focus(probeWindow);
    await until(() => query("activewindow").class === probeApp, "focus away");
    assert.equal(status().opened, true);
    assert.equal(halpClient().address, originalHalp.address);
    ipc("summon", "yzjm.halp", "{}");
    await until(() => query("activewindow").address === originalHalp.address && query("activeworkspace").name === workspace.slice(5), "cross-workspace summon");
    console.log("PASS: dwindle layout, persistence on focus/workspace changes, go-to-HALP summon");

    dispatch(`hl.dsp.window.float({ window = ${selector(originalHalp)}, action = "toggle" })`);
    await until(() => halpClient().floating, "floating toggle");
    const result = execFileSync(process.execPath, [path.join(root, "tools/place-window.mjs"), String(originalHalp.pid),
        JSON.stringify({ floatingWidth: 640, floatingHeight: 480, anchor: "bottom-right" })], { encoding: "utf8" });
    assert.match(result, /Placement applied/);
    const monitor = query("monitors").find(item => item.id === halpClient().monitor);
    const expected = floatingRect(monitor, normalize({ floatingWidth: 640, floatingHeight: 480, anchor: "bottom-right" }, process.env.HOME));
    await until(() => halpClient().size[0] === 640 && halpClient().size[1] === 480
        && Math.abs(halpClient().at[0] - expected.x) <= 2 && Math.abs(halpClient().at[1] - expected.y) <= 2, "floating size and anchor");
    dispatch(`hl.dsp.window.close({ window = ${selector(originalHalp)} })`);
    await until(() => !status().opened && !halpClient(), "compositor close");
    assert.equal(ipc("ping"), "ok");
    focus(probeWindow);
    ipc("summon", "yzjm.halp", "{}");
    await until(() => status().opened && !!halpClient(), "reopen after close");
    assert.equal(halpClient().floating, false);
    ipc("hide", "yzjm.halp");
    await until(() => !status().opened && !halpClient(), "explicit hide");
    ipc("summon", "yzjm.halp", "{}");
    await until(() => status().opened && !!halpClient(), "reopen after hide");
    console.log("PASS: floating placement, compositor close, shell survival, Hide/reopen");

    settingsTouched = true;
    assert.equal(ipc("call", "yzjm.halp", "configure", '{"normalOpacity":0.91}'), "ok");
    await delay(500);
    const changedConfig = JSON.parse(await readFile(configPath, "utf8"));
    assert.equal(changedConfig.plugins.find(entry => entry.id === "yzjm.halp").normalOpacity, 0.91);
    assert.deepEqual(changedConfig.bar, originalConfig.bar, "Saving settings must preserve the bar configuration");
    assert.equal(ipc("setPluginEnabled", "yzjm.halp", "false"), "ok");
    await delay(400);
    assert.equal(ipc("call", "yzjm.halp", "status", ""), "unknown");
    assert.equal(halpClient(), undefined);
    const workers = execFileSync("ps", ["-eo", "args="], { encoding: "utf8" }).split("\n")
        .filter(line => /^node .*\/yzjm\.halp\/tools\/watch-packs\.mjs /.test(line));
    assert.deepEqual(workers, [], "Disabling HALP must terminate its watcher");
    assert.equal(ipc("setPluginEnabled", "yzjm.halp", "true"), "ok");
    await until(() => ipc("call", "yzjm.halp", "status", "").startsWith("{"), "plugin re-enable");
    ipc("call", "yzjm.halp", "configure", JSON.stringify(originalSettings));
    await delay(500);
    ipc("summon", "yzjm.halp", "{}");
    await until(() => status().opened && !!halpClient(), "summon after settings restoration");
    settingsTouched = false;
    console.log("PASS: scoped settings persistence, disable cleanup, re-enable");
} catch (error) {
    console.error(error.stack);
    if (probeLog) console.error(probeLog);
    process.exitCode = 1;
} finally {
    if (settingsTouched) {
        ipc("setPluginEnabled", "yzjm.halp", "true");
        await delay(500);
        ipc("call", "yzjm.halp", "configure", JSON.stringify(originalSettings));
        await delay(500);
        ipc("summon", "yzjm.halp", "{}");
    }
    probe?.kill();
    await rm(directory, { recursive: true, force: true });
    const remaining = halpClient();
    if (remaining) {
        if (remaining.floating) dispatch(`hl.dsp.window.float({ window = ${selector(remaining)}, action = "toggle" })`);
        const destination = initialWorkspace.id > 0 ? String(initialWorkspace.id) : "name:" + initialWorkspace.name;
        dispatch(`hl.dsp.window.move({ window = ${selector(remaining)}, workspace = ${JSON.stringify(destination)}, follow = true })`);
    }
    if (restoreFocus && query("clients").some(window => window.address === restoreFocus.address)) focus(restoreFocus);
}
