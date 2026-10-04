import path from "node:path";
import { scanFiles } from "./pack-files.mjs";
import { indexFiles } from "../js/FilenameRules.mjs";

const directory = path.resolve(process.argv[2] || path.join(process.env.HOME, ".config/halp/packs"));
const snapshot = await scanFiles(directory);
const result = indexFiles(snapshot.files);
for (const entry of result.entries) console.log(`${entry.kind.padEnd(5)} ${entry.id}`);
for (const error of [...snapshot.errors, ...result.errors]) console.error(error);
console.log(`${result.entries.length} references; ${snapshot.errors.length + result.errors.length} errors`);
process.exitCode = snapshot.errors.length || result.errors.length ? 1 : 0;
