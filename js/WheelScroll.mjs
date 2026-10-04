// Keep wheel distance linear, including fractional high-resolution packets.
// Qt Quick uses 24 logical pixels per system-configured wheel scroll line.
export function delta(pixelDelta, angleDelta, scrollLines, speed = 1, horizontal = false) {
    const pixels = pixelDelta.x !== 0 || pixelDelta.y !== 0;
    const input = pixels ? pixelDelta : angleDelta;
    const unit = pixels ? 1 : scrollLines * 24 / 120;
    let x = -input.x * unit * speed;
    let y = -input.y * unit * speed;
    if (horizontal && x === 0) { x = y; y = 0; }
    // The compositor already applies natural-scroll direction to these deltas.
    return { x, y };
}
