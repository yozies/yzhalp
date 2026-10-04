export const extensions = ["png", "jpg", "jpeg", "webp", "svg", "pdf"];
export const classNames = ["terminal", "browser", "editor", "any"];

export function supportedFile(path) {
    const extension = String(path).split(".").pop().toLowerCase();
    return extensions.includes(extension);
}

// The identity includes the pack and subdirectories, never just the basename.
export function parseFilename(relativePath) {
    const id = String(relativePath);
    const filename = id.split("/").pop();
    if (!supportedFile(filename)) throw new Error("Unsupported file extension");
    const dot = filename.lastIndexOf(".");
    const extension = filename.slice(dot + 1).toLowerCase();
    const stem = filename.slice(0, dot);
    const labelAt = stem.indexOf("--");
    const expression = labelAt < 0 ? stem : stem.slice(0, labelAt);
    const label = labelAt < 0 ? expression : stem.slice(labelAt + 2).trim();
    if (!label) throw new Error("Display label is empty");
    const parts = expression.split("~");
    if (parts.length > 2) throw new Error("Only one title separator (~) is supported");
    const titleContains = parts.length === 2 ? parts[1].trim() : null;
    if (titleContains === "") throw new Error("Title filter is empty");
    if (/[\*?]/.test(expression)) throw new Error("Use literal targets and title text, not wildcards");
    const targets = parts[0].split("+");
    for (const target of targets) {
        if (!target || /\s/.test(target)) throw new Error("Targets must be nonempty app IDs or @classes without spaces");
        if (target.startsWith("@") && !classNames.includes(target.slice(1)))
            throw new Error("Unknown application class: " + target);
    }
    return { id, filename, label, targets: Array.from(new Set(targets)), titleContains,
        extension, kind: extension === "pdf" ? "pdf" : "image" };
}

export function fileUrl(path) {
    return "file://" + String(path).split("/").map(encodeURIComponent).join("/");
}

export function indexFiles(files) {
    const entries = [];
    const errors = [];
    for (const file of files) {
        try {
            entries.push(Object.assign({}, parseFilename(file.relativePath), { path: file.path,
                url: fileUrl(file.path), revision: file.revision }));
        } catch (error) {
            errors.push(file.relativePath + ": " + error.message);
        }
    }
    return { entries, errors };
}
