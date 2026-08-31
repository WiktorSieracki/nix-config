# localsend — feature notes

2026-06-26: Added featureMeta + a feature test.

Symptom: `command -v localsend` returns "not found" despite the package being installed.
Cause: The upstream Flutter build names the binary `localsend_app`, not `localsend`.
Fix: The feature test asserts `command -v localsend_app`.

2026-08-31: Autostart into the tray.

localsend can only receive while it runs, so it is spawned at session start via
`flake.niriSpawnAtStartup` (the extension point added alongside `niriBinds`).
The `--hidden` flag is undocumented in `--help` but present in the binary
(alongside its in-app `autoStart` / `autoStartLaunchHidden` settings) and starts
the app minimised to the system tray. Do not use localsend's own in-app autostart
toggle: it writes `~/.config/autostart/*.desktop` at runtime, which would fight
this declaration.
