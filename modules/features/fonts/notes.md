# feature notes: fonts

*Last updated: 2026-09-17*

## Gotcha: "Segoe UI" resolved to Noto Sans CJK KR, mangling Polish (2026-09-17)

**Symptom**: in t3code (and any Electron/web UI) Polish text rendered wrong —
`ś` came out as `s` with the acute floating to its right, between `s` and the
next letter ("bezposŕednio"); `ł`, `ą`, `ę`, `ź`, `ż` looked like they came from
a different font than the words around them.

**Not a data bug**: the message text in `~/.t3/userdata/state.sqlite` is
precomposed NFC (`ś` = U+015B, verified) — the mangling happened at render time.

**Cause**, measured on desktopNixos with only `fonts.enableDefaultPackages`:

1. t3code's CSS names no font of its own —
   `--font-sans: -apple-system, BlinkMacSystemFont, "Segoe UI", system-ui, sans-serif`.
   The only `@font-face` it bundles is `SymbolsNerdFontMono` for terminal icons.
2. Chromium asks fontconfig for each name in turn, and fontconfig never fails a
   match. Stock `65-nonlatin.conf` expands `Segoe UI` / `system-ui` into a UI
   preference chain: Adwaita Sans → Cantarell → Noto Sans UI → … →
   **Noto Sans CJK KR** → … → DejaVu Sans. Nothing from the head was installed,
   so the first present family won:

   ```
   $ fc-match --format='%{family}' 'Segoe UI'     # before
   Noto Sans CJK KR
   ```

   (`FC_DEBUG=1 fc-match 'Segoe UI'` prints the whole expanded chain — that is
   how the ordering above was read off.)
3. Noto Sans CJK KR has **no precomposed Polish letters**: ą ę ł ś ź ż are all
   missing; only ń and ó are there. It does carry U+0301 COMBINING ACUTE, so
   HarfBuzz decomposed U+015B into `s` + U+0301 and drew the mark at the default
   advance — the font has no Latin mark-attachment anchors — hence the accent
   landing beside the letter instead of on it.

**Fix**: install a UI font that already sits at the *head* of that chain rather
than adding rules to fight it. `adwaita-fonts` (Adwaita Sans / Adwaita Mono,
7 MB closure, full Polish coverage) makes every Apple/Windows UI name resolve
correctly with no custom fontconfig XML:

| pattern              | before             | after        |
| -------------------- | ------------------ | ------------ |
| `Segoe UI`           | Noto Sans CJK KR   | Adwaita Sans |
| `system-ui`          | Noto Sans CJK KR   | Adwaita Sans |
| `-apple-system`      | DejaVu Sans        | Adwaita Sans |
| `BlinkMacSystemFont` | DejaVu Sans        | Adwaita Sans |
| `sans-serif`         | DejaVu Sans        | Adwaita Sans |
| `Menlo`              | DejaVu Sans (!)    | Adwaita Mono |

The feature test asserts that whole table, so a nixpkgs change to the stock
chains fails the build instead of quietly restoring the CJK match.

## Gotcha: fc-match's pattern syntax eats the hyphen

`fc-match ui-monospace` does **not** query the family `ui-monospace` — the CLI
pattern grammar is `family-size:style`, so it queries family `ui` and reports
whatever the sans default is. Early measurements of `system-ui`, `ui-monospace`
and `-apple-system` were wrong for this reason. Escape the hyphens:

```bash
fc-match --format='%{family}' 'system\-ui'
fc-match --format='%{family}' '\-apple\-system'
```

Chromium is unaffected — it passes families through the API, not this syntax.

## Where the rules land, and why the order matters

`fonts.fontconfig.defaultFonts` is written to `/etc/fonts/conf.d/52-nixos-default-fonts.conf`,
`fonts.fontconfig.localConf` to `/etc/fonts/local.conf` (pulled in by
`51-local.conf`). Both therefore run *before* `60-latin.conf` / `65-nonlatin.conf`,
and a later rule's `<prefer>` inserts ahead of an earlier one's. Consequence,
measured: an alias for `system-ui` in `localConf` is useless — by the time it
applies, the stock chain has already rewritten the pattern and the alias
matches only the leftover copy of the name at the tail of the family list.
Names the stock chains *don't* touch (`Menlo`, `Monaco`, `SF Mono`) do work
from `localConf`, which is why only those are aliased there.

`/etc/fonts/conf.d` is a single store directory (`fontconfig-conf`), so there is
no way to drop a `99-*.conf` in via `environment.etc` — `localConf` at 51 is the
latest hook NixOS offers.
