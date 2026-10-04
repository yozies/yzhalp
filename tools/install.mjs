import { mkdir, symlink, realpath, lstat, copyFile, readdir } from "node:fs/promises";
import { constants } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { execFileSync } from "node:child_process";
import { setTimeout as delay } from "node:timers/promises";

const root = fileURLToPath(new URL("..", import.meta.url));
const home = process.env.HOME;
const destination = path.join(home, ".config/omarchy/plugins/yzjm.halp");
const ipc = (...args) => execFileSync("omarchy-shell", ["shell", ...args], { encoding: "utf8" }).trim();
try {
    if (ipc("ping") !== "ok") throw new Error("Omarchy Shell is not running");
    await mkdir(path.dirname(destination), { recursive: true });
    try {
        await lstat(destination);
        if (await realpath(destination) !== await realpath(root))
            throw new Error("An existing installation occupies " + destination);
    } catch (error) {
        if (error.code !== "ENOENT") throw error;
        await symlink(root, destination);
    }
    const exampleDestination = path.join(home, ".config/halp/packs/halp-guide");
    await mkdir(exampleDestination, { recursive: true });
    for (const name of await readdir(path.join(root, "examples/halp-guide"))) {
        try { await copyFile(path.join(root, "examples/halp-guide", name), path.join(exampleDestination, name), constants.COPYFILE_EXCL); }
        catch (error) { if (error.code !== "EEXIST") throw error; }
    }
    const applications = path.join(home, ".local/share/applications");
    await mkdir(applications, { recursive: true });
    try { await copyFile(path.join(root, "assets/yzjm.halp.desktop"), path.join(applications, "yzjm.halp.desktop"), constants.COPYFILE_EXCL); }
    catch (error) { if (error.code !== "EEXIST") throw error; }
    const config = path.join(home, ".config/omarchy/shell.json");
    try { await copyFile(config, config + ".halp-backup-" + Date.now(), constants.COPYFILE_EXCL); }
    catch (error) { if (error.code !== "ENOENT") throw error; }
    ipc("rescanPlugins");
    let discovered = false;
    for (let i = 0; i < 40; i++) {
        if (JSON.parse(ipc("listPlugins")).some(plugin => plugin.id === "yzjm.halp")) { discovered = true; break; }
        await delay(100);
    }
    if (!discovered) throw new Error("Omarchy did not discover HALP");
    execFileSync("omarchy", ["plugin", "enable", "yzjm.halp"], { stdio: "inherit" });
    console.log("HALP installed at " + destination);
    console.log("Open: omarchy-shell shell summon yzjm.halp '{}'");
} catch (error) { console.error(error.message); process.exitCode = 1; }
