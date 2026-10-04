// Qt's SVG image reader applies the window DPR itself; raster/PDF requests
// specify physical pixels. Limit decoded output to 16 megapixels (~64 MiB).
export function renderSize(width, height, devicePixelRatio, automaticDpr) {
    const w = Math.max(1, Number(width) || 1);
    const h = Math.max(1, Number(height) || 1);
    const dpr = Math.max(1, Number(devicePixelRatio) || 1);
    const readerScale = automaticDpr ? dpr : 1;
    const desiredScale = automaticDpr ? 1 : dpr;
    const scale = Math.min(desiredScale, 8192 / (w * readerScale), 8192 / (h * readerScale),
        Math.sqrt(16 * 1024 * 1024 / (w * h)) / readerScale);
    return { width: Math.max(1, Math.floor(w * scale)), height: Math.max(1, Math.floor(h * scale)) };
}
