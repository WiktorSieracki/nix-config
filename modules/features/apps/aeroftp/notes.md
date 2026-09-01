# aeroftp — feature notes

2026-09-01: Added as a packaged .deb (upstream v4.1.9, Tauri 2 + React, GPL-3.0).

Symptom: the upstream AppImage exits with `libgdk-3.so.0: cannot open shared
object file`.
Cause: the AppImage bundles no GTK/webkit and expects a Debian-shaped system.
Fix: package the `.deb` instead and let `autoPatchelfHook` link it against
nixpkgs' `webkitgtk_4_1`/`gtk3` — the same reasoning as `buzz`. Wrapping the
AppImage with `appimageTools` (the `handy` route) would keep the Debian library
expectations instead of resolving them.

Symptom: `aftp` / `aeroftp-cli` would open the GUI instead of the CLI if the
package were wrapped normally.
Cause: `usr/bin/aeroftp` is a small Rust dispatcher; all three names are the same
binary and it picks GUI vs CLI from `argv[0]` (`route_from_argv0`) and the
subcommand. `wrapGAppsHook3`'s automatic wrapper execs through a
`.aeroftp-wrapped` path, which erases `argv[0]`.
Fix: `dontWrapGApps = true` plus one explicit `makeWrapper … --argv0 <name>` per
name in `postFixup`.

The dispatcher locates the real binaries at `../lib/aeroftp` relative to
`/proc/self/exe`, falling back to `/usr/lib/aeroftp`. That is why the dispatcher
is installed to `$out/libexec/aeroftp-dispatch` — one level under `$out`, so
`../lib/aeroftp` resolves to `$out/lib/aeroftp`. Moving it into `$out/bin` keeps
working by accident; moving it deeper does not.

`libayatana-appindicator` (tray) is `dlopen`'d, so it is absent from `NEEDED` and
has to be listed in `runtimeDependencies` rather than `buildInputs`.
`glib-networking` is the libsoup TLS backend — without it every https transfer
fails at runtime.

The .deb also ships a polkit action + update helper (`com.aeroftp.update`) and a
nautilus-python extension. Neither is installed: self-updating a store path is a
no-op at best, and the version is pinned here instead.
