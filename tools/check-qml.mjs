import { mkdtemp, symlink, rm, readdir } from "node:fs/promises";
import { tmpdir } from "node:os";
import { fileURLToPath } from "node:url";
import path from "node:path";
import { spawnSync } from "node:child_process";

const root = fileURLToPath(new URL("..", import.meta.url));
const imports = await mkdtemp(path.join(tmpdir(), "halp-qml-imports-"));
try {
    await symlink((process.env.OMARCHY_PATH || "/usr/share/omarchy") + "/shell", path.join(imports, "qs"));
    const files = ["HalpPlugin.qml", ...(await readdir(path.join(root, "qml"))).filter(name => name.endsWith(".qml")).map(name => "qml/" + name)];
    const result = spawnSync("/usr/lib/qt6/bin/qmllint", ["-I", imports, "-I", "/usr/lib/qt6/qml",
        "--unqualified", "info", "--max-warnings", "0", ...files], { cwd: root, stdio: "inherit" });
    if (result.error) throw result.error;
    process.exitCode = result.status;
} finally { await rm(imports, { recursive: true, force: true }); }
