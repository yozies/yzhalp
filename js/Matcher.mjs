export const applicationClasses = {
    terminal: ["foot", "footclient", "kitty", "alacritty", "com.mitchellh.ghostty",
        "ghostty", "org.wezfurlong.wezterm", "wezterm", "org.gnome.terminal",
        "org.kde.konsole", "xterm"],
    browser: ["firefox", "org.mozilla.firefox", "librewolf", "zen", "zen-browser",
        "chromium", "chromium-browser", "google-chrome", "google-chrome-stable",
        "brave-browser", "brave-browser-beta", "vivaldi-stable", "microsoft-edge"],
    editor: ["code", "code-oss", "codium", "vscodium", "dev.zed.zed", "zed",
        "sublime_text", "org.gnome.texteditor", "org.kde.kate", "neovide", "gvim"]
};

export function specificity(sheet, context, classes = applicationClasses) {
    const appId = String(context.appId || "");
    const title = String(context.title || "");
    const hasTitle = sheet.titleContains !== null;
    if (hasTitle && !title.toLowerCase().includes(sheet.titleContains.toLowerCase())) return -1;
    let best = -1;
    for (const target of sheet.targets) {
        let rank = -1;
        if (target === "@any") rank = 0; // Always a fallback, even with a title filter.
        else if (target.startsWith("@")) {
            if ((classes[target.slice(1)] || []).includes(appId.toLowerCase())) rank = hasTitle ? 3 : 1;
        } else if (target === appId) rank = hasTitle ? 4 : 2;
        best = Math.max(best, rank);
    }
    return best;
}

function compare(a, b) { return a < b ? -1 : a > b ? 1 : 0; }

export function matchingSheets(entries, context) {
    return entries.map(sheet => Object.assign({}, sheet, { specificity: specificity(sheet, context) }))
        .filter(sheet => sheet.specificity >= 0)
        .sort((a, b) => b.specificity - a.specificity
            || compare(a.label.toLowerCase(), b.label.toLowerCase()) || compare(a.id, b.id));
}

export function selectedId(matches, previousId, contextChanged) {
    if (!contextChanged && matches.some(sheet => sheet.id === previousId)) return previousId;
    return matches.length ? matches[0].id : "";
}
