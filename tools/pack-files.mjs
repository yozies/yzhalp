import { readdir, stat } from "node:fs/promises";
import path from "node:path";
import { supportedFile } from "../js/FilenameRules.mjs";

export async function scanFiles(root) {
    const files = [];
    const errors = [];
    async function walk(directory) {
        let entries;
        try { entries = await readdir(directory, { withFileTypes: true }); }
        catch (error) {
            errors.push(directory + ": " + error.code);
            return;
        }
        for (const entry of entries) {
            if (entry.name.startsWith(".")) continue;
            const fullPath = path.join(directory, entry.name);
            if (entry.isDirectory()) await walk(fullPath);
            else if (entry.isFile() && supportedFile(entry.name)) {
                try {
                    const info = await stat(fullPath, { bigint: true });
                    files.push({ path: fullPath, relativePath: path.relative(root, fullPath),
                        revision: `${info.mtimeNs}:${info.ctimeNs}:${info.size}:${info.ino}` });
                } catch (error) { if (error.code !== "ENOENT") errors.push(fullPath + ": " + error.code); }
            }
        }
    }
    await walk(root);
    files.sort((a, b) => a.relativePath < b.relativePath ? -1 : a.relativePath > b.relativePath ? 1 : 0);
    return { files, errors };
}
