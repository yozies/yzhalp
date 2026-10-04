import { watch } from "node:fs";
import { mkdir, stat } from "node:fs/promises";
import path from "node:path";
import { scanFiles } from "./pack-files.mjs";

const root = path.resolve(process.argv[2] || ".");
let watcher;
let watchedInode;
let timer;
let scanning = false;
let pending = false;
let previous = "";

function schedule() {
    clearTimeout(timer);
    timer = setTimeout(refresh, 80);
}

async function refresh() {
    if (scanning) { pending = true; return; }
    scanning = true;
    try {
        try {
            const info = await stat(root);
            if (info.ino !== watchedInode) { watcher?.close(); watcher = undefined; }
            if (!watcher) {
                watcher = watch(root, { recursive: true }, schedule);
                watchedInode = info.ino;
                watcher.on("error", () => { watcher?.close(); watcher = undefined; schedule(); });
            }
        } catch { watcher?.close(); watcher = undefined; watchedInode = undefined; }
        // Starting the watcher before scanning closes the startup event gap.
        const snapshot = { root: process.argv[2] || ".", ...await scanFiles(root) };
        const encoded = JSON.stringify(snapshot);
        if (encoded !== previous) { process.stdout.write(encoded + "\n"); previous = encoded; }
    } finally {
        scanning = false;
        if (pending) { pending = false; schedule(); }
    }
}

// Creating the default content directory is the only filesystem write by this helper.
try { await mkdir(root, { recursive: true }); } catch { /* Report through the snapshot. */ }
await refresh();
// Recover from a removed/replaced root, missed watcher events, or watch limits.
const recovery = setInterval(refresh, 3000);
function stop() { clearInterval(recovery); clearTimeout(timer); watcher?.close(); process.exit(0); }
process.on("SIGTERM", stop);
process.on("SIGINT", stop);
process.stdout.on("error", stop);
