# quickshell — feature notes

## 2026-08-22 — initial rewrite, replacing noctalia

The whole system UI moved from noctalia (a prebuilt quickshell-based shell)
to this hand-rolled quickshell config. What noctalia provided vs. what this
feature covers now:

- **Covered in QML**: top bar (clock, cpu/mem, active window, per-output
  workspaces via `niri msg --json event-stream`, tray, battery, volume),
  app launcher (Mod+Space), session menu (Mod+P), notification daemon +
  popups, volume OSD.
- **Handed to dedicated tools** (spawned from niri.nix): wallpaper → swaybg
  (static, the `wallpapers` feature's file), idle/screen-off/lock-on-suspend
  → swayidle, lock screen → swaylock (needs `security.pam.services.swaylock`).
- **Dropped, deliberately**: control center, weather/calendar, dock,
  night light, notification history, clipboard integration, desktop widgets,
  and the runtime color-scheme templates (pywalfox/discord/spicetify/code/
  niri/ghostty). Ghostty now ships a static `theme = GruvboxDark` line
  instead of the noctalia-generated theme file.

## IPC generation drift (inherited lesson)

quickshell matches a running instance by its `-p <config>` path. The
`quickshell-ui-ipc` wrapper resolves the *running* process's path at
invocation time — same trick as the old noctalia-ipc — so niri binds keep
working when the running shell and the current generation diverge. Don't
bind `qs -p <store path> ipc ...` directly.

## Why the feature test can't exercise the shell

The headless test VM has no GPU/Wayland session, so the QML never runs in
CI — the niri feature test only asserts the bins exist on PATH. QML
regressions surface on `nh os test` + a live session (`quickshell-ui` in a
terminal prints QML errors to stderr; it runs fine as a second instance for
smoke-testing, apart from the notification daemon failing to register while
another daemon owns org.freedesktop.Notifications — that error is expected
and non-fatal).
