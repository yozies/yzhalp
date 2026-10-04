import { execFileSync } from "node:child_process";
import { floatingRect, normalize } from "../js/Preferences.mjs";

try {
    const pid = Number(process.argv[2]);
    const settings = normalize(JSON.parse(process.argv[3]), process.env.HOME);
    const query = name => JSON.parse(execFileSync("hyprctl", ["-j", name], { encoding: "utf8" }));
    const client = query("clients").find(window => window.pid === pid && window.title === "HALP");
    if (!client) throw new Error("HALP's window is not mapped yet");
    if (!client.floating) throw new Error("Float HALP with Super+T before applying placement");
    const monitors = query("monitors");
    const monitor = settings.monitor ? monitors.find(item => item.name === settings.monitor)
        : monitors.find(item => item.id === client.monitor);
    if (!monitor) throw new Error("The selected monitor is not connected");
    const rect = floatingRect(monitor, settings);
    const window = JSON.stringify("address:" + client.address);
    function dispatch(lua) {
        const result = execFileSync("hyprctl", ["dispatch", lua], { encoding: "utf8" });
        if (result.trim() !== "ok") throw new Error(result.trim());
    }
    if (client.monitor !== monitor.id) {
        const destination = monitor.activeWorkspace.id > 0 ? String(monitor.activeWorkspace.id)
            : "name:" + monitor.activeWorkspace.name;
        dispatch(`hl.dsp.window.move({ window = ${window}, workspace = ${JSON.stringify(destination)}, follow = true })`);
    }
    dispatch(`hl.dsp.window.resize({ window = ${window}, x = ${rect.width}, y = ${rect.height}, relative = false })`);
    dispatch(`hl.dsp.window.move({ window = ${window}, x = ${rect.x}, y = ${rect.y}, relative = false })`);
    process.stdout.write("Placement applied");
} catch (error) { process.stderr.write(error.message + "\n"); process.exitCode = 1; }
