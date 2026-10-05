# HALP

**Your hand-designed references, automatically selected for the application you're using.**

HALP is an Omarchy 4 Quattro plugin written in QML and JavaScript. Drop your own
PNG, JPEG, WebP, SVG or PDF references into local pack folders. The filenames say
when to show them; the artwork supplies the design.

Maintainers and coding agents: [technical specification](docs/technical-specification.md).

## Install on Omarchy

Requires Omarchy Shell, Quickshell 0.3.1+, Node.js 22+, Qt 6 SVG/image plugins, and
`QtQuick.Pdf`. On this Arch/Omarchy installation, the PDF module is provided by
`qt6-webengine`, with image support from `qt6-svg` and `qt6-imageformats`.
There are no npm dependencies and no build step.

From this checkout:

```sh
npm run install-local
omarchy-shell shell summon yzjm.halp '{}'
```

The installer:

- Links this checkout into `~/.config/omarchy/plugins/yzjm.halp`.
- Enables the plugin through Omarchy's supported CLI.
- Adds a **HALP** application-launcher entry.
- Copies an example SVG into `~/.config/halp/packs/halp-guide/`, preserving any
  existing copy.
- Backs up `shell.json` before enabling the plugin.

Keep the checkout in place while using this linked installation. Pack files live
outside the plugin source, so changing your references refreshes the viewer
without reloading Omarchy plugins.

## Name your references

Default content directory:

```text
~/.config/halp/packs/
```

Files are discovered recursively. Example:

```text
packs/personal/
├── @any--Omarchy.pdf
├── firefox--Firefox.png
├── @browser~Gmail--Gmail.pdf
├── @terminal~NVIM--Neovim.svg
└── @terminal~.rs--Rust.webp
```

Grammar:

```text
<target>[+<target>...][~<title-contains>][--<label>].<extension>
```

| Part | Meaning |
| --- | --- |
| `firefox` | Exact, case-sensitive application ID |
| `@terminal`, `@browser`, `@editor` | Built-in application groups |
| `@any` | An always-available fallback |
| `+` | Either application target may match |
| `~Gmail` | Window title contains this literal text, ignoring case |
| `--Gmail` | Human-readable tab label |

Examples: `firefox+chromium~Gmail--Mail.pdf`, `@any--My reference.svg`.

Exact app + title matches rank first, followed by class + title, exact app,
class, then `@any`. An `@any` target stays a fallback even when title-filtered.
Ties sort by label and then the complete pack-relative path. Every matching
reference remains available in the tabs.

Use **⋯ → Context / diagnostics** to inspect real application IDs and titles.
Terminal programs usually share the terminal's app ID: a Neovim/Git/Docker
reference needs a matching terminal-title rule, or `@any` if the terminal title
doesn't identify the program.

See [the filename contract](docs/filename-format.md) for edge cases.

## Window behavior

- HALP starts hidden and stays loaded while enabled.
- Summon opens it on the active workspace, following the workspace's layout.
- Summon while already open focuses the existing window and its workspace.
- Focus changes, including monitor and workspace switches, leave it open.
- Interacting with HALP retains the last external application context.
- **Super+T** toggles normal floating/tiling. Floating placement controls are
  under Settings; tiled geometry is owned by Hyprland.
- **Hide**, **Ctrl+W**, or the compositor's close shortcut hides HALP.
- Shell/plugin reloads can close it; summon it again afterwards.

Use `summon`, rather than the shell's `toggle`, for a global “go to HALP” shortcut.

```lua
-- Choose an unused binding in ~/.config/hypr/bindings.lua.
o.bind("SUPER + H", "Show HALP", "omarchy-shell shell summon yzjm.halp '{}'")
```

Check existing bindings before adding one. If you override a binding, unbind it
first. After Hyprland configuration changes, run `hyprctl reload` and
`hyprctl configerrors`.

The optional rules in [integration/halp.lua](integration/halp.lua) give HALP full
compositor opacity, so only the document's alpha and your HALP opacity setting
affect the artwork. They also explicitly request tiling on initial mapping.
The local installer leaves keybindings and Hyprland rules for you to choose.

## Viewer controls

| Control | Action |
| --- | --- |
| Wheel / touchpad / drag | Scroll and pan |
| `j`, `k`, Up, Down | Scroll vertically |
| Left, Right | Pan a zoomed reference |
| Shift + wheel | Pan horizontally |
| Ctrl+D, Ctrl+U, Page Down, Page Up | Half-page scroll |
| `g g`, Home | Top |
| `G`, End | Bottom |
| `+`, `-` | Zoom in/out |
| `0`, Fit | Fit the width |
| `[`, `]` | Previous/next matching sheet |
| `1`–`9` | Select a matching sheet |
| `/`, Ctrl+F | Filter matching filenames/labels |
| Ctrl+W, Hide | Hide HALP |
| Escape | Dismiss the filter, menu or settings |

The default view fits the widest PDF page or the image to the available width.
Manual zoom keeps its scale during resizing; Fit follows width changes. PDF pages
are rendered lazily, with a small nearby-page buffer. New selections begin at the
top. Replacing a selected reference reloads it from the top too.

Wheel and touchpad movement is applied directly, preserving high-resolution and
subpixel deltas. HALP adds no wheel velocity cap or flick animation, so fast
gesture-based scrollers remain responsive. **Scroll speed** in Settings defaults
to **100%**, using Qt's system wheel-line setting (or the supplied touchpad pixel
distance), and can be adjusted from 25% to 400%. Touch/mouse dragging retains
Flickable's normal gesture behavior. Keyboard scrolling uses its own fixed steps.

Zoomed render requests are capped at 16 megapixels per image/page. SVG requests
account for Qt's automatic display scaling, so large references remain usable
on HiDPI displays without overflowing Qt's image allocation limit.

Artwork retains its original colours and layout. Omarchy's `Color` and `Style`
singletons theme the controls. The surface around documents is transparent; PDF
pages have white paper. Hover fade is optional and off by default. Settings use
an opaque themed background for legibility.

Encrypted PDFs show a message asking for an unlocked reference copy. SVG files
use Qt SVG's supported SVG features. The filename filter searches reference names;
it doesn't depend on extracting or recognizing document text.

## Settings and diagnostics

Open **⋯ → Settings**. Preferences live inline in HALP's entry in
`~/.config/omarchy/shell.json` and are saved through the scoped plugin API.
The current host may recreate the panel on settings changes; summon again if
it closes after Save. Apply floating placement after using Super+T.

Supported settings: `packsPath`, `scrollSpeed`, `normalOpacity`, `hoverFade`, `hoverOpacity`,
`debug`, `floatingWidth`, `floatingHeight`, `anchor`, `monitor`, `offsetX`, `offsetY`.
Floating offsets use logical pixels: positive X is right, positive Y is down.
Placement respects monitor scale, rotation and reserved areas, and is clamped
to the usable monitor area.

```sh
omarchy-shell shell call yzjm.halp configure '{"hoverFade":true,"hoverOpacity":0.35}'
omarchy-shell shell call yzjm.halp status ''
node tools/validate-pack.mjs ~/.config/halp/packs
```

The validator checks supported filenames and matching metadata. Rendering errors
are reported by the viewer. Unreadable directories and invalid filenames appear
in diagnostics; healthy references continue to work.

## Development and checks

```sh
npm test           # Matching, preferences, watcher recovery and atomic replacement
npm run test:scroll # Real Qt wheel events: fine packets, fast bursts and panning
npm run lint      # Qt 6 qmllint with Omarchy's real theme imports
npm run smoke     # Offscreen Qt rendering; requires ImageMagick for raster fixtures
npm run check     # All of the above
npm run integration  # Explicit live-desktop check against an installed HALP
```

The smoke check executes the shared modules inside Qt's JavaScript engine as well
as rendering every supported image family, PDFs, malformed documents, narrow and
large 2×-scaled viewports, and settings. Captures are written to a temporary directory printed by
the command. Quickshell's JS engine has a smaller language subset than Node;
shared modules deliberately avoid object-spread syntax.

The integration check creates a temporary probe window and reference pack,
changes focus, moves only HALP to an isolated workspace, tests floating/closing,
saves/restores HALP settings, and disables/re-enables the plugin. It then removes
its fixtures and restores HALP's original workspace and external
focus. Run it when brief desktop movement is convenient.

For development, `omarchy-shell shell rescanPlugins` rediscovers manifests, but
this host can retain previously compiled QML/ES modules. Use
`omarchy restart shell` to reliably pick up plugin code changes. Reference-file
changes do not need this. `HALP_PACKS_PATH` can override the content directory for
an isolated development shell.

The runtime uses one managed Node process for filesystem discovery/watch events,
with a three-second recovery scan for missed events or a recreated pack root.
Matching and context changes are handled in-process; they do not spawn commands.

## Remove

Disable HALP with `omarchy plugin disable yzjm.halp`, then remove the installation
symlink and `~/.local/share/applications/yzjm.halp.desktop` when no longer needed.
Your reference files remain in `~/.config/halp/packs/`.
