import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, mkdir, writeFile, rename, rm, symlink } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { spawn } from "node:child_process";
import { createInterface } from "node:readline";
import { setTimeout as delay } from "node:timers/promises";
import { scanFiles } from "../tools/pack-files.mjs";

test("watcher observes nested adds, atomic replacements, deletion and root recreation", { timeout: 18000 }, async t => {
    const directory = await mkdtemp(path.join(tmpdir(), "halp-watch-"));
    const packs = path.join(directory, "packs with spaces");
    const child = spawn(process.execPath, [fileURLToPath(new URL("../tools/watch-packs.mjs", import.meta.url)), packs]);
    let latest;
    let stderr = "";
    child.stderr.on("data", chunk => { stderr += chunk; });
    const lines = createInterface({ input: child.stdout });
    lines.on("line", line => { latest = JSON.parse(line); });
    t.after(async () => { child.kill(); lines.close(); await rm(directory, { recursive: true, force: true }); });
    async function until(predicate) {
        for (let i = 0; i < 180; i++) { if (latest && predicate(latest)) return latest; await delay(30); }
        assert.fail("Watcher timed out: " + JSON.stringify(latest) + stderr);
    }
    await until(snapshot => snapshot.files.length === 0 && !snapshot.errors.length);
    const nested = path.join(packs, "personal", "日本");
    await mkdir(nested, { recursive: true });
    const filename = path.join(nested, "@any--C# + notes.svg");
    await writeFile(filename, "first");
    const first = await until(snapshot => snapshot.files.length === 1);
    assert.equal(first.files[0].relativePath, "personal/日本/@any--C# + notes.svg");
    const revision = first.files[0].revision;
    await writeFile(filename + ".tmp", "replacement");
    await rename(filename + ".tmp", filename);
    await until(snapshot => snapshot.files[0]?.revision !== revision && snapshot.files.length === 1);
    await rm(filename);
    await until(snapshot => snapshot.files.length === 0);
    await rm(packs, { recursive: true });
    await until(snapshot => snapshot.errors.length > 0);
    await mkdir(packs);
    await writeFile(path.join(packs, "@any--Restored.pdf"), "pdf placeholder");
    await until(snapshot => snapshot.files.length === 1 && snapshot.files[0].relativePath === "@any--Restored.pdf");
});

test("discovery ignores hidden files, unsupported formats and symlink loops", async t => {
    const root = await mkdtemp(path.join(tmpdir(), "halp-index-"));
    t.after(() => rm(root, { recursive: true, force: true }));
    await writeFile(path.join(root, "@any--Guide.PNG"), "image");
    await writeFile(path.join(root, ".@any--Hidden.png"), "hidden");
    await writeFile(path.join(root, "@any--Notes.txt"), "text");
    await symlink(root, path.join(root, "loop"));
    const result = await scanFiles(root);
    assert.equal(result.files.length, 1);
    assert.equal(result.errors.length, 0);
});
