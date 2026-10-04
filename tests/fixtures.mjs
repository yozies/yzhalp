// A tiny, real two-page PDF with different page sizes; offsets are computed in bytes.
export function samplePdf() {
    const streams = [
        "0.1 0.3 0.4 rg 30 30 540 840 re f\nBT /F1 28 Tf 1 1 1 rg 60 800 Td (HALP - page one) Tj ET\n",
        "0.3 0.2 0.5 rg 30 30 740 1140 re f\nBT /F1 28 Tf 1 1 1 rg 60 1100 Td (HALP - page two) Tj ET\n"
    ];
    const objects = [
        "<< /Type /Catalog /Pages 2 0 R >>",
        "<< /Type /Pages /Kids [3 0 R 5 0 R] /Count 2 >>",
        "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 600 900] /Resources << /Font << /F1 7 0 R >> >> /Contents 4 0 R >>",
        `<< /Length ${Buffer.byteLength(streams[0])} >>\nstream\n${streams[0]}endstream`,
        "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 800 1200] /Resources << /Font << /F1 7 0 R >> >> /Contents 6 0 R >>",
        `<< /Length ${Buffer.byteLength(streams[1])} >>\nstream\n${streams[1]}endstream`,
        "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"
    ];
    let output = "%PDF-1.4\n";
    const offsets = [0];
    objects.forEach((object, index) => {
        offsets.push(Buffer.byteLength(output));
        output += `${index + 1} 0 obj\n${object}\nendobj\n`;
    });
    const xref = Buffer.byteLength(output);
    output += `xref\n0 ${objects.length + 1}\n0000000000 65535 f \n`;
    for (const offset of offsets.slice(1)) output += `${String(offset).padStart(10, "0")} 00000 n \n`;
    output += `trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF\n`;
    return output;
}
