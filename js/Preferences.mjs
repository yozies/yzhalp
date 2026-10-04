export const anchors = ["top-left", "top", "top-right", "left", "centre", "right",
    "bottom-left", "bottom", "bottom-right"];

function bounded(value, fallback, min, max) {
    return typeof value === "number" && Number.isFinite(value)
        ? Math.min(max, Math.max(min, value)) : fallback;
}

export function normalize(entry, home) {
    const value = entry || {};
    let packsPath = typeof value.packsPath === "string" ? value.packsPath.trim() : "";
    if (packsPath.startsWith("~/")) packsPath = home + packsPath.slice(1);
    if (!packsPath.startsWith("/")) packsPath = home + "/.config/halp/packs";
    return {
        packsPath,
        scrollSpeed: bounded(value.scrollSpeed, 1, 0.25, 4),
        normalOpacity: bounded(value.normalOpacity, 1, 0.15, 1),
        hoverOpacity: bounded(value.hoverOpacity, 0.35, 0.05, 1),
        hoverFade: value.hoverFade === true,
        debug: value.debug === true,
        floatingWidth: Math.round(bounded(value.floatingWidth, 800, 260, 7680)),
        floatingHeight: Math.round(bounded(value.floatingHeight, 700, 180, 4320)),
        anchor: anchors.includes(value.anchor) ? value.anchor : "top-right",
        monitor: typeof value.monitor === "string" ? value.monitor : "",
        offsetX: Math.round(bounded(value.offsetX, 0, -7680, 7680)),
        offsetY: Math.round(bounded(value.offsetY, 0, -4320, 4320))
    };
}

export function floatingRect(monitor, preferences) {
    const rotated = [1, 3, 5, 7].includes(monitor.transform);
    const scale = monitor.scale || 1;
    const reserved = monitor.reserved || [0, 0, 0, 0];
    const areaWidth = (rotated ? monitor.height : monitor.width) / scale - reserved[0] - reserved[2];
    const areaHeight = (rotated ? monitor.width : monitor.height) / scale - reserved[1] - reserved[3];
    const width = Math.min(preferences.floatingWidth, areaWidth);
    const height = Math.min(preferences.floatingHeight, areaHeight);
    const anchor = preferences.anchor;
    const horizontal = anchor.includes("left") ? 0 : anchor.includes("right") ? 1 : 0.5;
    const vertical = anchor.includes("top") ? 0 : anchor.includes("bottom") ? 1 : 0.5;
    const left = monitor.x + reserved[0];
    const top = monitor.y + reserved[1];
    return {
        x: Math.round(Math.max(left, Math.min(left + areaWidth - width,
            left + (areaWidth - width) * horizontal + preferences.offsetX))),
        y: Math.round(Math.max(top, Math.min(top + areaHeight - height,
            top + (areaHeight - height) * vertical + preferences.offsetY))),
        width: Math.round(width), height: Math.round(height)
    };
}
