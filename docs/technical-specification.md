# HALP V0.1 — Technical specification

Status: implemented unless marked PLANNED.
Audience: maintainers and coding agents. Replaces the historical conversation.

## 1. Product contract

```text
External appId + title ──┐
                        ├─> filename matching ─> ranked tabs ─> image/PDF viewer
Local reference packs ──┘
```

- Display hand-authored reference artwork; preserve its typography and layout.
- Omarchy 4 Quattro only; no cross-desktop abstraction or custom C++ backend.
- Offline runtime: ordinary local files; no AI or network service required.
- Superseded: `.halp` text parsing, generated cards, MaxRects packing, text outlines.

## 2. Stack and ownership

| Layer | Contract |
| --- | --- |
| Host | Omarchy Shell; plugin ID `yzjm.halp` |
| UI | QML / Qt Quick; Quickshell 0.3.1+ |
| Logic | Functional `.mjs` modules; plain serializable models |
| Filesystem | One managed Node.js 22+ discovery/watcher process |
| Context | `Quickshell.Wayland.ToplevelManager` |
| Images | Qt Quick `Image`; Qt SVG and image-format plugins |
| PDF | `QtQuick.Pdf`; lazily instantiated `PdfPageImage` delegates |
| Theme | Host `qs.Commons.Color` and `Style` singletons |

```text
HalpPlugin.qml                 lifecycle, selection, activation, diagnostics
qml/
├── ContextTracker.qml         last external toplevel + scalar context
├── PackIndex.qml              watcher process + validated index
├── SettingsStore.qml          shell.json read + scoped API save
├── HalpView.qml                toolbar, tabs, filter, keyboard dispatch
├── ImageSheet.qml              image Flickable
├── PdfSheet.qml                variable-height PDF ListView
├── NativeWheelArea.qml         direct wheel/gesture input
└── SettingsPane/HalpButton     controls
js/
├── FilenameRules.mjs           grammar, file URLs, index validation
├── Matcher.mjs                 classes, ranking, selection
├── Preferences.mjs             defaults, validation, floating geometry
├── RasterSize.mjs              HiDPI-aware render allocation limits
└── WheelScroll.mjs             linear input-delta conversion
tools/                         install, discovery, placement, validation, checks
```

Shared JS must run in both Node and Qt's JS engine. Avoid object-spread syntax;
Node tests alone do not establish Qt compatibility.

## 3. Lifecycle and window

Manifest: `schemaVersion: 1`, `kinds: ["panel"]`, `keepLoaded: true`,
`entryPoints.panel: "HalpPlugin.qml"`; entry root is an `Item`.

```text
enabled ─> loaded, hidden
hidden  ── summon/open(payloadJson) ─> visible on active workspace
visible ── summon ──────────────────> activate existing window + workspace
visible ── Hide / Ctrl+W / WM close ─> hidden; notify host via shell.hide()
disable / remove / shell shutdown ──> unload; terminate managed processes
host plugin reload/rescan ──────────> may close/recreate; next summon reopens
```

- Single `FloatingWindow`, title `HALP`, transparent native background.
- Normal compositor client despite the type name; tiled by default.
- Inherit workspace layout, insertion order and scrolling-column width.
- Focus, monitor and workspace changes must not dismiss it.
- Workspace switches hide it with that workspace, not unmap it.
- `Super+T`: compositor floating/tiling toggle.
- Floating controls: monitor, anchor, dimensions, offsets; apply explicitly.
- Placement respects logical pixels, scale, rotation and reserved areas.
- Initial floating size: 800×700; native minimum size: 260×180.
- Use scoped third-party shell APIs; do not assume access to host internals.
- Global launch action uses `summon`, not visibility `toggle`.

## 4. Context

| Event | Result |
| --- | --- |
| External toplevel focus | Capture `appId` and `title`; rematch |
| Tracked appId/title changes | Rematch |
| HALP focus | Preserve last external context |
| Null active toplevel | Preserve last external context |
| Tracked window closes | Release object; retain scalar snapshot |
| Summon | Capture external context before activation; suppress transient activation focus |

Self identification: `appId === Quickshell.appId && title === "HALP"`.
Normal windows share the shell's process-wide app ID; class alone is insufficient.

Diagnostics: app ID, title, matching paths, selected path, index/load errors.
IPC: `status()`, `selectSheet(id)`, `navigate(action)`, `configure(payloadJson)`.

## 5. Files and discovery

```text
~/.config/halp/packs/<pack>/<optional subdirectories>/<reference file>
```

- Formats: PNG, JPG/JPEG, WebP, SVG, PDF; extensions ignore case.
- Identity: complete pack-root-relative path, not basename.
- Recursively discover regular files; skip hidden entries and child symlinks.
- Root may be a symlink; never follow recursive symlink loops.
- Watch before initial scan; debounce changes 80 ms; recovery scan every 3 s.
- Add/remove/rename/atomic replacement: refresh index and relevant viewer live.
- Revision: filesystem timestamps, size and inode; disable stale image caching.
- Encode file URLs by path segment; preserve spaces, Unicode, `#`, `%`, `+`.
- Invalid rules/unreadable folders: diagnostics; healthy references remain usable.
- Runtime override: `HALP_PACKS_PATH`; otherwise use saved `packsPath`.

## 6. Filename matching and tabs

```text
<target>[+<target>...][~<title-contains>][--<label>].<extension>

firefox--Firefox.png
firefox+chromium~Gmail--Mail.pdf
@terminal~NVIM--Neovim.svg
@any--Omarchy defaults.pdf
```

| Operator | Meaning |
| --- | --- |
| exact appId | Literal, case-sensitive match |
| `@terminal`, `@browser`, `@editor` | Known app-ID groups; membership ignores case |
| `@any` | Fallback, including before external context is known |
| `+` | OR between targets |
| `~text` | Literal, case-insensitive title substring; applies to every target |
| `--label` | Display label; absent label defaults to matching expression |

No fuzzy matching, regex, wildcard or operator escaping.
Reject empty targets/labels/filters, whitespace in targets, unknown classes,
multiple `~` separators, and `*`/`?` in expressions.

| Rank, highest first | Match |
| --- | --- |
| 4 | Exact app + title |
| 3 | Class + title |
| 2 | Exact app |
| 1 | Class |
| 0 | `@any`, including title-filtered fallback |

- OR rule rank = strongest target that actually matched.
- Tie break: lowercase label, then relative path; code-point ordering.
- All matches remain tabs; context change selects highest rank.
- Manual tab selection persists within the same app/title context.
- File refresh retains selection if still matching; deletion selects next best.
- New selection or selected-file replacement starts at the top.
- `/` filters matching names/labels, not document text.
- Detailed grammar: [filename-format.md](filename-format.md).

## 7. Rendering and input

| Area | Behavior |
| --- | --- |
| Artwork | Preserve aspect ratio and authored colours; transparent surround |
| Fit | Image width / widest PDF page fits viewport width |
| Resize | Fit follows width; manual zoom retains scale; height changes viewport |
| PDF | Variable page sizes; white paper; nearby-page buffer; lazy rendering |
| Render limits | 16 megapixels and 8192-pixel dimensions per request; account for SVG's automatic DPR |
| Errors | Readable loading/error/empty states; encrypted PDFs require unlocked copy |
| Hover fade | Optional; artwork only; default off |
| Theme | Controls react to host colours/font/metrics; do not parse theme files independently |

```text
pixelDelta available -> use directly
otherwise            -> angleDelta / 120 × system wheelScrollLines × 24 px
then                  -> optional scrollSpeed multiplier -> clamp to content bounds
```

- Preserve fractional/high-resolution packets and both axes.
- No wheel velocity cap, throttling, extra animation or synthesized momentum.
- Respect compositor-provided scroll direction; do not invert it again.
- Drag/flick gestures remain owned by Flickable; wheel input cancels an active flick.

| Input | Action |
| --- | --- |
| wheel/touchpad; Shift+wheel | scroll/pan; horizontal pan |
| `j`/`k`, Up/Down; Left/Right | vertical scroll; horizontal pan |
| Ctrl+D/U, Page Down/Up | half-page |
| `g g`/Home; `G`/End | top; bottom |
| `+`/`-`; `0`/Fit | zoom; fit width |
| `[`/`]`; `1`–`9` | cycle tabs; select tab |
| `/`/Ctrl+F; Escape | filename filter; dismiss UI |
| Ctrl+W / Hide | hide HALP |

## 8. Settings

Persistence: inline entry in `~/.config/omarchy/shell.json`, `plugins[]`.
Read with `FileView`; save through scoped `shell.updateEntryInline()`.
Preserve unknown entry fields. Host may recreate panel after Save.

| Field | Default | Constraints |
| --- | --- | --- |
| `packsPath` | `~/.config/halp/packs` | absolute path; expand `~/` |
| `scrollSpeed` | 1 | 0.25–4; system-relative 100% |
| `normalOpacity` | 1 | 0.15–1 |
| `hoverOpacity` | 0.35 | 0.05–1 |
| `hoverFade`, `debug` | false | boolean |
| `floatingWidth` | 800 | 260–7680 |
| `floatingHeight` | 700 | 180–4320 |
| `anchor` | top-right | nine positions below |
| `monitor` | empty | current monitor; otherwise output name |
| `offsetX` | 0 | −7680–7680; positive right |
| `offsetY` | 0 | −4320–4320; positive down |

```text
top-left      top       top-right
left          centre    right
bottom-left   bottom    bottom-right
```

## 9. Verification contract

```text
npm test             matching, preferences, allocation limits, watcher recovery
npm run lint         Qt 6 QML checks against host imports
npm run test:scroll   real Qt wheel events on image and PDF views
npm run smoke        Qt JS + formats, errors, narrow/HiDPI rendering
npm run check        all noninteractive checks
npm run integration  explicit live desktop lifecycle/placement/settings checks
```

Acceptance checklist:
- [ ] Images and multi-page PDFs load without breaking the shell.
- [ ] Context/ranking/tabs/self exclusion follow sections 4–6.
- [ ] Content edits refresh without plugin reload or window recreation.
- [ ] Repeated summon reuses and activates the existing window/workspace.
- [ ] Hide/WM close/reopen and disable cleanup work.
- [ ] Equivalent coarse/fine wheel deltas yield equivalent movement.
- [ ] Fast input, reversal, bounds, panning, drag and scrollbar feedback work.
- [ ] Theme/settings changes and HiDPI rendering remain valid.

## 10. Content distribution — PLANNED

```text
HALP application repository -> code, docs, synthetic test fixtures
Separate reference packs   -> artwork, attribution, downloadable versions
Local installed packs      -> ~/.config/halp/packs/ (offline runtime)
```

- Target: optional Omarchy starter pack; versioned static/GitHub Release downloads.
- Retain original source credits and applicable distribution terms.
- Current installer still copies a bundled welcome SVG; tests also use it.
- Pending: replace it with synthetic fixtures, remove automatic content copy,
  define pack metadata/install tooling, establish separately distributed packs.
- Final pack catalogue and grouping are not yet decided.
