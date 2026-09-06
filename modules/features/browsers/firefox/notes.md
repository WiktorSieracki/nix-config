# feature notes: firefox

The Firefox browser feature with an HM profile, bookmarks and extensions from firefox-addons.

## Gotchas

**2026-06-26** — Extensions from `firefox-addons` are fixed-output derivations fetched from addons.mozilla.org.
Symptom: `nix build .#checks.x86_64-linux.feature-firefox` fails with a network error or timeout in a sandboxed environment.
Cause: `programs.firefox.profiles.wiktor.extensions.packages` tries to fetch the extensions while building the VM test.
Fix: The feature test uses `extraHmModules` with `lib.mkForce []` to zero out the extension list — we only check that the `firefox` binary is on PATH.

**2026-09-06** — Firefox showed a "restore session" button instead of just reopening the tabs.
Two independent causes, only one of them fixable here.

*Cause 1 (fixed):* `browser.startup.page` was never declared, so it sat at its default
`1` (= open the homepage). Firefox then merely *offers* to restore, tracked by
`browser.startup.couldRestoreSession.count` in `prefs.js` — that counter had reached 2.
Setting the pref to `3` makes both shutdown paths reopen the tabs directly; the feature
test now asserts the pref reaches the generated `user.js`.

*Cause 2 (upstream, not fixable in this config):* every logout counts as a Firefox crash.
niri runs Firefox in `app-niri-firefox-*.scope`; on logout systemd stops the scope, and
Firefox exits on SIGTERM in ~250 ms **without** writing the clean-shutdown marker
`sessionstore.jsonlz4`. Measured directly, and visible in the real profile: after a
session that ran until 00:06, `sessionstore-backups/previous.jsonlz4` still carried the
mtime of the last *clean* exit, and the session recorded `recentCrashes: 3`. Upstream
[bug 336193](https://bugzilla.mozilla.org/show_bug.cgi?id=336193) is still NEW after 17
years (SIGTERM was partly addressed for Linux by bug 1837907, but not for sessionstore).
With `browser.startup.page = 3` the crash-recovery path restores anyway, so this only
costs whatever happened since the last `browser.sessionstore.interval` flush.

*Dead end — do not re-try:* `browser.sessionstore.max_resumed_crashes` looks like the
knob that gates the button screen, and isn't. Rewriting a profile's `recovery.jsonlz4`
with `recentCrashes: 4` and `session.state: "running"` (fallback `recovery.baklz4`
deleted, a marker URL proving Firefox read the rewritten file) still auto-restored on
Firefox 155. Raising that pref would be cargo cult.
