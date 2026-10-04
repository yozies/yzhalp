import { test } from "node:test";
import assert from "node:assert/strict";
import { parseFilename, fileUrl, indexFiles } from "../js/FilenameRules.mjs";
import { matchingSheets, specificity, selectedId } from "../js/Matcher.mjs";
import { normalize, floatingRect } from "../js/Preferences.mjs";
import { renderSize } from "../js/RasterSize.mjs";

test("filename grammar preserves labels, title dots, OR targets and pack identity", () => {
    const sheet = parseFilename("personal/languages/@terminal+code~.rs--Rust reference.PDF");
    assert.deepEqual(sheet.targets, ["@terminal", "code"]);
    assert.equal(sheet.titleContains, ".rs");
    assert.equal(sheet.label, "Rust reference");
    assert.equal(sheet.kind, "pdf");
    assert.equal(sheet.id, "personal/languages/@terminal+code~.rs--Rust reference.PDF");
    assert.notEqual(sheet.id, parseFilename("other/@terminal+code~.rs--Rust reference.PDF").id);
});

test("malformed rules are diagnosed individually without dropping healthy references", () => {
    const bad = ["--Empty.png", "foo+--Empty.pdf", "@unknown.svg", "foo~--Empty.jpg",
        "foo~one~two.pdf", "foo--.svg", "foo*.png", "has space.png"];
    for (const name of bad) assert.throws(() => parseFilename(name), undefined, name);
    const result = indexFiles([...bad, "@any--Good.webp"].map(name => ({ relativePath: name,
        path: "/packs/" + name, revision: "1" })));
    assert.equal(result.entries.length, 1);
    assert.equal(result.errors.length, bad.length);
});

test("URLs retain literal #, %, Unicode, + and whitespace in filenames", () => {
    const filename = "/packs/日本/@any--C# + 100% notes.png";
    assert.equal(new URL(fileUrl(filename)).pathname,
        "/packs/%E6%97%A5%E6%9C%AC/%40any--C%23%20%2B%20100%25%20notes.png");
    assert.equal(decodeURIComponent(new URL(fileUrl(filename)).pathname), filename);
});

test("ranking uses the strongest target that actually matched, not an unmatched exact target", () => {
    const context = { appId: "firefox", title: "INBOX — Gmail" };
    const sheets = ["@any--Fallback.pdf", "@browser--Browser.svg", "firefox--Firefox.png",
        "chromium+@browser~gmail--Mail.pdf", "firefox~Gmail--Specific.pdf"].map(parseFilename);
    assert.deepEqual(matchingSheets(sheets, context).map(sheet => sheet.label),
        ["Specific", "Mail", "Firefox", "Browser", "Fallback"]);
    assert.equal(specificity(parseFilename("chromium+@browser~gmail.pdf"), context), 3);
    assert.equal(specificity(parseFilename("Firefox.png"), context), -1);
    assert.equal(specificity(parseFilename("@browser~work.pdf"), context), -1);
    assert.equal(specificity(parseFilename("@any~gmail.pdf"), context), 0);
});

test("tabs have deterministic ties and retain manual selection only within the same context", () => {
    const entries = ["b/@any--Guide.pdf", "a/@any--Guide.svg", "z/@any--Alpha.png"].map(parseFilename);
    const matches = matchingSheets(entries, { appId: "", title: "" });
    assert.deepEqual(matches.map(sheet => sheet.id), [entries[2].id, entries[1].id, entries[0].id]);
    assert.equal(selectedId(matches, entries[0].id, false), entries[0].id);
    assert.equal(selectedId(matches, entries[0].id, true), entries[2].id);
    assert.equal(selectedId(matches, "removed", false), entries[2].id);
    assert.equal(selectedId([], "removed", false), "");
});

test("preferences validate malformed inputs and floating placement respects scale and reserved areas", () => {
    const values = normalize({ packsPath: "~/References", normalOpacity: 4,
        hoverOpacity: "oops", floatingWidth: 600, floatingHeight: 400, anchor: "bottom-right" }, "/home/me");
    assert.equal(values.packsPath, "/home/me/References");
    assert.equal(values.normalOpacity, 1);
    assert.equal(values.hoverOpacity, 0.35);
    const monitor = { x: 1920, y: 0, width: 2560, height: 1440, scale: 2, reserved: [0, 30, 0, 0], transform: 0 };
    assert.deepEqual(floatingRect(monitor, values), { x: 2600, y: 320, width: 600, height: 400 });
    const rotated = floatingRect({ ...monitor, transform: 1 }, { ...values, floatingWidth: 5000, offsetX: 999 });
    assert.equal(rotated.width, 720);
    assert.equal(rotated.x, 1920);
    assert.equal(rotated.y, 880);
});

test("render requests account for SVG's automatic DPR and bound decoded pixel allocation", () => {
    assert.deepEqual(renderSize(500, 700, 2, true), { width: 500, height: 700 });
    assert.deepEqual(renderSize(500, 700, 2, false), { width: 1000, height: 1400 });
    for (const automatic of [false, true]) {
        for (const dpr of [1, 1.5, 2, 3]) {
            const size = renderSize(7600, 14000, dpr, automatic);
            const scale = automatic ? dpr : 1;
            assert.ok(size.width * size.height * scale * scale <= 16 * 1024 * 1024);
            assert.ok(size.width * scale <= 8192 && size.height * scale <= 8192);
        }
    }
});
