# Filename matching contract — V0.1

```text
targets[~title][--label].extension
```

- Extensions: `.png`, `.jpg`, `.jpeg`, `.webp`, `.svg`, `.pdf`, ignoring case.
- Targets are separated by `+`, which is OR. A title condition applies to all
  targets together: `(target A OR target B) AND title contains text`.
- An app ID is compared literally and case-sensitively. Class membership uses
  the known IDs in `js/Matcher.mjs`, ignoring case.
- Classes: `@terminal`, `@browser`, `@editor`, `@any`.
- Title matching is a case-insensitive substring comparison, with no regex,
  fuzzy matching, globbing, or inferred process inspection.
- The first `--` introduces the label. With no label, the matching expression
  itself labels the tab. Labels may include further `--`, spaces and Unicode.
- Matching expressions reserve `+`, `~`, `--` and leading `@`. V0.1 has no escape
  syntax for these operators. Wildcards `*` and `?` are rejected in expressions.
- Empty targets, whitespace inside targets, unknown classes, repeated `~`,
  empty title filters and empty explicit labels are invalid.
- Filesystem paths are encoded as URLs by segment, so spaces, `#`, `%`, Unicode
  and `+` in paths are not interpreted as URL syntax.
- Hidden files/directories and symlink entries under a pack are skipped. A pack
  root itself may be a symlink. Symlink directories aren't traversed recursively.
- Identity is the full path relative to the pack root. Equal basenames in two
  different folders are separate references; hover a tab to see its path.

## Ranking

1. Exact application + title
2. Application class + title
3. Exact application
4. Application class
5. `@any` fallback (including a title-filtered fallback)

For a rule with several targets, only targets actually matching the current app
contribute to its rank. Within a rank, compare lowercased labels and then full
relative paths using deterministic code-point ordering.

A context change selects the highest-ranked reference. Manually selecting a tab
holds that selection within the same app/title context. File changes retain the
selection if it still matches; removing it selects the new highest-ranked file.
Null focus and HALP's own surface preserve the last external context.

## Examples

| Filename | Matches |
| --- | --- |
| `firefox--Browser shortcuts.png` | The `firefox` app ID |
| `firefox+chromium~Gmail--Mail.pdf` | Firefox/Chromium titles containing Gmail |
| `@browser~GitHub--GitHub.svg` | A known browser with GitHub in its title |
| `@terminal~NVIM--Neovim.pdf` | A known terminal with NVIM in its title |
| `@terminal~.rs--Rust.webp` | A terminal title containing `.rs` |
| `@any--My notes.pdf` | Any context, including before an external window is known |

These names select existing artwork. No information about the content is inferred
from the document itself, and no sidecar metadata is needed.
