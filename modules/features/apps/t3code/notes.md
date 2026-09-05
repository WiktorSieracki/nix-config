# t3code — feature notes

[pingdotgg/t3code](https://github.com/pingdotgg/t3code) — a minimal web GUI for
coding agents. The nixpkgs package ships two binaries; we use one:

- **`t3`** — the Node server + CLI (`serve`, `pair`, `auth`, `project`). The
  server owns the projects, files, git state, terminals and agent sessions;
  every client (browser, phone) is just a WebSocket client of it. Feature
  `t3code-server` runs it as a user service.
- **`t3code-desktop`** — the Electron client. **Deliberately not installed**; see
  "The desktop app is not a client of this server" below. Feature `t3code` is
  the client instead: a launcher entry that opens the server in a chromeless
  browser window.

The canonical docs are `docs/user/*.md` **in the upstream repo**, not the
mintlify site — the site is stale (it still documents a `--auth-token` flag that
0.0.33 no longer has).

## Packaging

- **2026-08-29 — dropped the hand-rolled AppImage.** nixpkgs now has `t3code`,
  which builds from source with pnpm+electron and ships *both* binaries, the
  desktop entry, icons and shell completions. That removed ~90 lines of
  `appimageTools.extract` + `autoPatchelfHook` + the `appendRunpaths libglvnd`
  ANGLE workaround documented in [orca's notes](../orca/notes.md). Everything
  below about GPU processes and `dlopen("libEGL.so.1")` is now nixpkgs' problem.
- nixpkgs is a `symlinkJoin` that wraps every binary with a **PATH prefix of the
  agents t3code should drive** (`enableCodex` and `enableGitHub`/`enableGit` on
  by default; `enableClaude`, `enableOpencode`, … off). We override it:
  `enableClaude = true` with `claude-code` pointed at the **llm-agents** package,
  so t3code drives the exact same `claude` the `claude-code` feature installs
  rather than a second copy from nixpkgs; and `enableCodex = false`, since no
  account here is logged into codex. t3code resolves a provider by binary name
  (Settings → provider → "Binary path: claude"), so PATH is the whole contract.
- nixpkgs lags upstream (0.0.33 vs 0.0.36 at the time of writing). A client
  newer than the server shows a version-mismatch warning in Settings →
  Connections; it does not refuse to connect.

## Remote access from a phone

`t3code-server` runs `t3 serve --host 127.0.0.1 --tailscale-serve`.

- **Loopback + Tailscale Serve, not `--host 0.0.0.0`.** `--tailscale-serve` asks
  Tailscale Serve to terminate HTTPS on the MagicDNS name
  (`https://<host>.<tailnet>.ts.net/`, port 443) and proxy to the local backend,
  so the listener never faces another interface and no firewall port is opened.
  0.0.33 binds loopback under `--tailscale-serve` even with no `--host`; we pass
  it anyway so the unit states its own contract.
- The Serve mapping is **torn down when the server stops** (`Tailscale Serve
  disabled { servePort: 443 }` in the journal), so nothing is left published
  after `systemctl --user stop t3code`. The upstream doc's claim that the
  mapping persists until `tailscale serve --https=443 off` describes
  `t3 pair --tailscale` against a server that was not started with the flag.
- HTTPS is not cosmetic: the hosted web app at `https://app.t3.codes` cannot
  connect to a plain `http://100.x.y.z:3773` backend (browsers block an HTTPS
  page from opening an insecure WebSocket). A plain tailnet-IP endpoint only
  works from the mobile app or an HTTP page.
- `tailscale serve` needs no sudo here because the `tailscale` feature sets
  `--operator=wiktor`. It does need the tailnet's **HTTPS certificates** feature
  enabled in the admin console (`tailscale status --json | jq .CertDomains`
  must be non-empty).
- The unit deliberately sets no `PATH`. The systemd user manager already
  inherits `/run/current-system/sw/bin`, and `requires = ["tailscale"]` is what
  guarantees the `tailscale` binary is there.
- `Restart = on-failure` is the ordering fix: `tailscaled` is a *system* unit, so
  a user unit cannot `After=` it, and `tailscale serve` fails until the tailnet
  is up.

### Pairing a device

Pairing is a one-time token, not a long-lived password: the device exchanges the
token for a session, and later access is session-based.

```bash
t3 pair                 # mint a token for the running server, print it as a QR code
t3 pair --ttl 1h --label phone
t3 auth session list    # inspect / revoke what is paired
```

`t3 pair` picks the running server *itself* and, with the Electron app open,
picks the wrong one — it reported `Pairing with desktopNixos
(http://127.0.0.1:3774)`, the app's backend, not the unit on 3773. The token is
still usable against the unit, because both servers share the auth tables in the
one `~/.t3/userdata/state.sqlite`; only the printed URL's port is wrong. One more
reason to keep the app closed on a host running `t3code-server`.

Everything arriving through Tailscale Serve is proxied from localhost, so
`t3 auth session list` shows every remote device as `127.0.0.1` — the phone is
`client: phone | mobile | Android | Chrome | 127.0.0.1`. The IP column tells you
nothing about *which* device paired, so always pass `--label`.

`t3 serve` also prints a token + QR at startup, so the first one is in
`journalctl --user -u t3code` — but in 0.0.33 that startup URL is the **loopback**
one (`http://localhost:3773/pair#token=...`), useless from a phone, even with
`--tailscale-serve`. Only `t3 pair --tailscale` prints the tailnet URL:

```text
Pairing URL: https://desktopnixos.tail87a44c.ts.net/pair#token=DCC6NE55F9SM
Expires: <now + 5 minutes>
```

Open that on the phone (or scan the QR). `--ttl` buys more than the 5-minute
default.

### Lingering

The NixOS half sets `users.users.<account>.linger = true` for every account that
enables the feature (via the loader's `hostUsers`). Without it the user manager
— and the server — would only exist between login and logout, which defeats the
point of reaching this machine from a phone.

### Activating a rebuild restarts the server — and kills its agent sessions

**2026-09-05, measured.** This home-manager generation activates user units with
**sd-switch** (`grep sd-switch $(readlink -f ~/.local/state/home-manager/gcroots/current-home)/activate`),
so any change to `t3code.service` — a new `t3` store path from a nixpkgs bump is
enough — restarts it on `nh os switch`/`test`. The server owns its provider
sessions: every agent running inside it dies with it, mid-task, including an
agent that is itself doing the rebuild. Rebuild when nothing is mid-flight, and
never let an agent activate a generation that bumps its own t3code.

### The desktop app spawns its own backend

**2026-08-29, measured.** *(This section's verdict — "use a browser" — was
reversed on 2026-09-05: the app is the client now, run with an isolated
`T3CODE_HOME` so the collision below cannot happen, because preview needs
Electron. The measurements themselves still hold.)* The Electron app always spawns *its own* backend; it
never attaches to a running one. Both orders were observed:

- app first → it holds `127.0.0.1:3773` and the unit crash-loops on
  `EADDRINUSE` (`Restart = on-failure` retried 91× and took the port the moment
  the app was closed — the retry is doing real work, not papering over a race);
- unit first → the app quietly takes the next free port, `127.0.0.1:3774`.

They are not isolated, though. Both processes hold the **same** database open:

```console
$ ls -l /proc/<unit-pid>/fd /proc/<app-pid>/fd | grep sqlite
/home/wiktor/.t3/userdata/state.sqlite{,-shm,-wal}   # both
```

The app's backend takes no `--base-dir`, so it defaults to `~/.t3` like the unit.
SQLite in WAL mode tolerates two writers, but each server keeps its own in-memory
projections of the event log (`Projections*`, `OrchestrationEvents` migrations),
so the two views drift apart. Upstream assumes one server per user.

So on a host that runs `t3code-server`, **the browser is the desktop client**:
`http://localhost:3773` locally, the MagicDNS URL from the phone — one server,
one database, the same threads everywhere.

Which is why the Electron binary never reaches a profile. `t3CliFor` links
`bin/t3` and keeps the package's icons and completions, but drops
`share/applications`, so `t3code-desktop` is neither on PATH nor in the
launcher. Nothing enforces this beyond the derivation — putting plain
`pkgs.t3code` in `home.packages` would quietly put the trap back.

## The client: the Electron app, pointed at its own backend

**2026-09-05 — replaced the chromeless browser window.** Feature `t3code` used
to be `t3code-web`, a `brave --app=http://localhost:3773` window. It was
dropped, with its launcher entry, when preview turned out to be Electron-only
(see *Browser preview is Electron-only* below): a browser client can never show
the preview panel or host an agent's `preview_*` calls, and that was judged
worth a second, idle backend. Any browser still reaches the server at
`http://localhost:3773` if you want a tab — it just has no preview.

`t3codeAppFor` installs one wrapper, `t3code-desktop`:

```bash
export T3CODE_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/t3code-desktop"
export T3CODE_PORT=3799
exec <t3code>/bin/t3code-desktop --ozone-platform=wayland "$@"
```

Every line of it is load-bearing:

- **`T3CODE_HOME` is the whole safety story.** The app always forks its own
  backend and cannot be told not to (`DesktopConfig` has no attach-to-server
  option; `T3CODE_DESKTOP_WS_URL` is not one either — see below). Pointed at a
  data directory of its own, that backend never opens the unit's
  `~/.t3/userdata/state.sqlite`, which is what made the app a trap before.
- **`T3CODE_PORT=3799`** keeps it off 3773, so the unit does not lose its
  listener and the app does not silently land on the next free port.
- **`--ozone-platform=wayland`** — nixpkgs' t3code wrapper only prefixes PATH, so
  the `NIXOS_OZONE_WL` idiom used by `discord.nix` does nothing here. Electron's
  `--ozone-platform-hint=auto` reads the session environment: measured
  2026-09-05, with `WAYLAND_DISPLAY` set but `XDG_SESSION_TYPE` unset it chose
  X11 and the app died instantly on `Missing X server or $DISPLAY`. The explicit
  flag depends on no session state.
- **`StartupWMClass = "t3code"`** — measured, like the old one:

  ```console
  $ niri msg -j windows      # after launching t3code-desktop
  't3code' | T3 Code (Alpha)
  ```

The app's own backend is not idle, it is just useless to you: the window loads
`t3code://app/`, and `ElectronProtocol.ts` proxies that scheme to
`targetOrigin`, i.e. to the app's own `http://127.0.0.1:3799`. So it serves the
UI, it appears in the environment list as "this environment", and it holds an
empty database. **Nothing of yours should live there** — a thread or project
created on the app's local environment lands in that database and is invisible
from the phone. Always pick `desktopNixos`.

### Pairing the app to the unit (one-time)

```bash
t3 pair --label t3code-desktop --ttl 30m
#   → Pairing URL: http://127.0.0.1:3773/pair#token=…
```

In the app: **Settings → Connections → Remote environments → Add environment**,
paste the whole pairing URL into **Host** — `parsePairingUrlFields` splits it
into host + code by itself — and submit. The toast says *"The environment is
saved and will reconnect on app startup"*, and it does; the credential lives in
`T3CODE_HOME`, so it survives rebuilds and only has to be redone if that
directory is wiped.

With the app's data directory isolated, `t3 pair` also stops picking the wrong
server: the trap noted above (with the app open, `t3 pair` reports the app's
backend) needed both servers to share `~/.t3`.

### Still true from the browser-window era

- `t3 auth session list` is a poor liveness check: `last connected` does not
  refresh on every websocket reconnect. To see whether a client is really
  attached, look at the sockets instead — `ss -tnp state established | grep
  :3773` names the process holding them.
- The entry lives in home-manager (`xdg.desktopEntries`), so `t3code` may not
  sit in a host's `system` list — the loader hard-fails on that.
- `xdg.desktopEntries` is installed as a home-manager **package**
  (`home.packages`, upstream `modules/misc/xdg/desktop-entries.nix`), so under
  `useUserPackages` the file is
  `/etc/profiles/per-user/<login>/share/applications/t3code.desktop` — *not*
  `~/.local/share/applications/`. That path carries the login, so it can't be a
  static `provides.files` line; the feature test asserts it by hand.

`T3CODE_DESKTOP_WS_URL` looks like it would point the app at an existing server,
but in `dist-electron` it is only a member of `DESKTOP_BACKEND_ENV_NAMES` — the
list of variables the app forwards *to the backend it spawns itself*. It is
undocumented; don't build on it.

### What we deliberately do not use

`t3 service install` writes a **mutable** `~/.config/systemd/user/t3code.service`
and self-updates the server version behind systemd's back. That is the opposite
of how this repo works; the declarative unit above replaces it. Don't run it.

## Browser preview is Electron-only — a browser client cannot have it

**2026-09-04, measured.** T3 Code's browser preview — the right-hand preview
panel *and* the `preview_*` MCP toolkit an agent drives it with — is unavailable
in **every** browser client: this feature's `t3code-web` window, any other
browser pointed at the server, and the hosted app at `https://app.t3.codes`
(same SPA build, same gates). This is not nixpkgs lag. The gates are identical
in the 0.0.33 running here (0.0.34 in the current `flake.lock`, unbuilt) and on
upstream `main` (0.0.39-nightly, read 2026-09-04), so upgrading does not fix it.

Two independent gates, both keyed on the Electron preload bridge:

| What                          | Upstream file                                             | Gate                                                                                                                                       |
| ----------------------------- | --------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| the human's preview panel     | `apps/web/src/components/preview/PreviewPanel.tsx`        | `isPreviewSupportedInRuntime()` = `Boolean(window.desktopBridge?.preview)`; false renders the text *"Preview is only available in the T3 Code desktop app."* |
| the agent's `preview_*` tools | `apps/web/src/components/preview/PreviewAutomationHosts.tsx` | `if (!isElectron || !previewBridge?.automation) return null` — the client never registers an automation host                                |

`isElectron` is `window.desktopBridge !== undefined` (`apps/web/src/env.ts`),
injected by the Electron preload before app code runs. A plain Chromium — which
is exactly what `t3code-web` is — never has it. There is no flag, setting or
env var behind these gates; they are unconditional.

Measured from an agent session on this host, against the running unit:

```console
$ preview_status          # MCP tool, t3code server on 127.0.0.1:3773
No preview automation host is available for status in environment
2d099815-…                # PreviewAutomationNoAvailableHostError
```

The **server** half is complete and innocent: `t3` ships the whole preview stack
(`apps/server/src/preview/Manager.ts`, `apps/server/src/mcp/PreviewAutomationBroker.ts`,
`apps/server/src/mcp/toolkits/preview/`) and advertises all 14 `preview_*` tools
over MCP, so an agent sees the tools and only finds out at call time. The broker
is a *router*, not an executor: it queues each operation to whichever client
connected as a `PreviewAutomationHost` for that `environmentId` and waits for
the answer. With browsers as the only clients, nobody ever connects, and every
call fails on the routing step.

**Why it cannot become an iframe.** The preview is not a viewport, it is an
automated browser: the desktop half (`apps/desktop/src/preview/{BrowserSession,
GuestProtocol,PlaywrightInjectedRuntime}.ts`) drives an Electron `<webview>` —
snapshots the guest DOM, injects synthetic clicks and keystrokes, screenshots
and records it — and the web half reaches that guest with
`document.querySelectorAll("webview[data-preview-tab]")` + `executeJavaScript`.
Same-origin policy forbids all of that against a cross-origin `<iframe>`, and
`X-Frame-Options`/CSP frequently forbid even the framing. So this is a web
platform limit, not a missing feature — don't wait for it to land in a browser
build.

### What this costs here, and the ways out

Until 2026-09-05 the `t3code` feature made a browser the client and dropped
`t3code-desktop` (see *The desktop app spawns its own backend* above). Preview
was the undocumented price of that trade. The three ways out, and what was
chosen:

1. **Leave it.** No preview panel for the human, no `preview_*` for agents on
   this host; an agent has to fall back to another browser tool. Zero risk.
   *Rejected* — preview was worth more than an idle second backend.
2. **Add an Electron client next to the server** and pair it to the running unit
   as a *saved environment*. `PreviewAutomationHosts` registers one host per
   connected environment and the broker routes by `environmentId`, so an
   Electron client attached to the unit's environment hosts previews for
   sessions that run there — the upstream `docs/user/remote-access.md` model
   ("Every saved environment is offered, not only the local one"). **Measured
   end to end on 2026-09-05 (recipe and its four surprises below) and then
   implemented: this is what feature `t3code` now installs.**
3. **Preview from another machine's desktop app** over the tailnet — still
   available, and the only option for the laptop. Same mechanism, one extra
   catch: for a *remote* environment,
   `apps/web/src/browser/browserTargetResolver.ts` rewrites a loopback preview
   URL to the environment's host — `localhost:5173` becomes
   `http://desktopnixos.tail87a44c.ts.net:5173` (`direct-private-network`), so
   the dev server must bind a non-loopback address and be reachable on the
   tailnet. Tailscale Serve only proxies 443, so it does not cover this.

### Measured: an Electron client paired to the unit does host previews

**2026-09-05.** Option 2 was run end to end on `desktopNixos` against the live
`t3code` unit, and it works: `preview_status` went from
`PreviewAutomationNoAvailableHostError` to `available: true`, and
`preview_open` / `preview_click` / `preview_snapshot` drove a real page from an
agent session on the unit's environment. What it took:

```bash
# 1. the app, with its own backend on its own data dir, so the unit's
#    ~/.t3/userdata/state.sqlite is never opened twice (see the drift above)
T3CODE_HOME=/tmp/t3-preview-probe T3CODE_PORT=3799 \
  t3code-desktop --ozone-platform=wayland

# 2. a pairing token for the *unit*, not for the app's own backend
t3 pair --label preview-host --ttl 30m
#   → Pairing URL: http://127.0.0.1:3773/pair#token=…
```

Then in the app: **Settings → Connections → Remote environments → Add
environment**, paste the whole pairing URL into **Host** — `parsePairingUrlFields`
splits it into host + code by itself — and submit. The unit is saved as an
environment named `desktopNixos`, its threads appear in the app's sidebar, and
`t3 auth session list` gains a
`preview-host | desktop | Linux x86_64 | Electron | 127.0.0.1` row.

Four things this measured that reading the code did not say:

- **`--ozone-platform=wayland` is required.** `--ozone-platform-hint=auto` picks
  X11 on this niri session and the app dies on the spot with
  `Missing X server or $DISPLAY`.
- **Isolating `T3CODE_HOME` also fixes `t3 pair`.** The trap noted above (with
  the app open, `t3 pair` reports the app's backend) does not apply here: the
  app's backend lives in the other data dir, so `t3 pair` still finds the unit.
- **The client is not a headless preview daemon — the thread has to be open in
  it.** With the environment paired but the thread not loaded in the app,
  `preview_status` already answers `available: true` while `preview_snapshot`
  fails with *"Preview snapshot failed"* (`UnknownVizError` in the returned
  `actionTimeline`): `ElectronBrowserHost` mounts a `webview[data-preview-tab]`
  only for preview sessions of threads the client has loaded, and
  `waitForDesktopOverlay` waits for exactly that element. Opening the thread in
  the app mounted the webview and the identical call returned the screenshot,
  DOM text and accessibility tree.
- **Opening a *running* thread in a second client moves the git checkout.**
  Measured the hard way: opening this thread in the app while an agent was
  working on a feature branch ran `git checkout main` in the repo
  (`git reflog`: `checkout: moving from docs/t3code-preview-desktop-only to
  main`) — the client restores the thread's recorded checkout, and the running
  agent's working tree goes with it. Commits already made survive on their
  branch; uncommitted work would not. Commit before attaching a second client
  to a live thread.

One more upstream quirk: **`preview_click` returns a result some MCP clients
reject**. The click itself landed (the tab navigated), but the tool answered
with `structuredContent: null`, which claude-code's MCP client refused as a
malformed result. Read a schema error from `preview_click` as "probably
clicked" and confirm with `preview_status`.

That probe was torn down afterwards (app killed, pairing session revoked with
`t3 auth session revoke <id>`, its data directory removed) and the recipe became
the feature: `t3codeAppFor` is the wrapper, and *Pairing the app to the unit*
above is the one step that stayed manual.

Scope of the check: browser clients and the Electron app. The native mobile app
is a separate client and was not examined.

## Updating

Bump nixpkgs (`nix flake update nixpkgs`). There is nothing version-shaped left
in this file. `passthru.updateScript` upstream tracks GitHub releases, so the
nixpkgs attr follows stable tags, not the several-times-a-day `*-nightly`
prereleases.
