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

**Since V2 (0.1.0) there is no local backend at all.** The wrapper sets
`localEnvironmentEnabled: false` in the app's `desktop-settings.json` before
every launch. See the 2026-10-16 section *One environment instead of two*.
The paragraphs above describe 0.0.x.

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

Redo it after changing the machine's `PRETTY_HOSTNAME`: the app copies the
environment's name when it pairs. On V2, `t3 pair` without `--scope` grants the
full client set (`settings:write`, `providers:manage`, `preview:operate`,
`filesystem:*`, …). A token minted under 0.0.x has only the narrow
orchestration/terminal scopes.

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

### The forked backend outlives the app and bricks the next launch (2026-09-19)

Measured on 0.0.40. The app's backend is a child of the main Electron process,
but nothing ties its lifetime to it: kill (or crash) the main process and the
backend is re-parented to `systemd`, still holding `T3CODE_PORT`. `ps` right
after the failure, with the main process already gone:

```
235299  ppid 1168  electron .../apps/server/dist/bin.mjs --bootstrap-fd 3
```

The next launch forks its own backend, which cannot bind the port and dies. The
app has no fallback — `DesktopConfig` cannot attach to a server it did not
start — so the renderer fails on the first IPC call it makes:

```
PrimaryEnvironmentRequestError
Caused by: Error invoking remote method
  'desktop:get-local-environment-bearer-token':
  DesktopLocalEnvironmentAuthSessionBootstrapError:
  Failed to create the local desktop bearer session.
```

The timestamps identify it with no ambiguity: the orphan's launch, the second
launch and the error are ~60 s, then 1 s apart. The message names auth, but
nothing about auth is wrong — a port is taken. Read it as "no local backend".

To confirm rather than guess: `ss -tlnp | grep 3799`, then check whether that
PID's parent is `systemd` (orphan) or an Electron main (healthy). Killing the
orphan and relaunching is the manual recovery; it is safe as long as the PID's
`T3CODE_HOME` is the app's `~/.local/share/t3code-desktop` and **not** the
unit's `~/.t3` — that one on 3773 is the server, and killing it takes every
agent session running inside it down mid-task.

Fixed at the source in `t3code.nix`: the wrapper launches the app into a
transient `systemd-run --user` **service**, so the backend lands in that unit's
cgroup and the default `KillMode=control-group` reaps it when the main process
exits. A `--scope` does not work here — a scope stays alive while any process in
it is alive, which is precisely the orphan. The cost is that the service is
started by the `systemd --user` manager, not by this shell, so it inherits the
manager's environment and none of ours: `T3CODE_HOME`, `T3CODE_PORT` and
`SSL_CERT_FILE` have to travel as `--setenv`, and the Wayland session variables
have to already be in the manager (niri puts them there).

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

## Antigravity's 502 is a missing CA bundle, not an outage

**2026-09-18.** Every Antigravity turn (both `gemini-3.8-flash-*` and
`gemini-3.7-flash-*`, across fresh logins) answered with:

```
Agent execution error: model unreachable: Error 502, Message: Bad Gateway:
Failed to connect to backend API …
```

The message is a lie about where it comes from. `agy_acp_server.par` logs to
`/tmp/agy_acp_server.par.<host>.<user>.log.ERROR.*`, and the traceback there is:

```
ccpa_client.py  urllib.request.urlopen(req, …)
ssl.SSLCertVerificationError: [SSL: CERTIFICATE_VERIFY_FAILED]
    unable to get local issuer certificate
  → CCPAConnectionError: Network connection failed to CCPA API
  → proxy_server.py do_POST → 502 Bad Gateway: Failed to connect to backend API
```

The 502 is minted **locally**, by the ACP server's own in-process proxy, after
its TLS handshake to `aicode.googleapis.com` fails. The `.par` carries an
embedded Python whose OpenSSL has no trust store on NixOS, and the process
environment held exactly one variable: `PYTHONUNBUFFERED=1`.

OAuth still succeeded throughout (`authenticate` → ok, `status: authenticated`),
because the login half runs in Node with the system certs — only the model call
goes through that Python. That split is what makes the failure read as a Google
outage. Upstream reports the same thing, oauth-personal only:
<https://discuss.ai.google.dev/t/antigravity-acp-502-bad-gateway-but-antigravity-ide-is-working-fine/179763>

Proven by driving the ACP protocol against the same `.par`, same token, same
shadow home, changing nothing but the variable:

| `SSL_CERT_FILE` | `session/prompt` result |
| --------------- | ----------------------- |
| unset           | `model unreachable: Error 502 …` |
| `/etc/ssl/certs/ca-certificates.crt` | the model's actual reply |

Hence `caBundle` in `t3code.nix`, exported in both places a backend can start
from: the `t3code` user unit (a unit inherits no shell profile, so a
`sessionVariables` entry would never reach it) and the Electron wrapper (the app
forks a backend of its own). Both are asserted in the feature tests.

The same trap waits for any other foreign agent binary t3code spawns — read a
provider-level "connection failed" against an endpoint that `curl` reaches fine
as a missing trust store first.

## 2026-10-08 — no window after the 0.0.44 bump: node-pty can't find libstdc++

Symptom: `t3code-desktop` starts, the Electron process stays alive, but no
window ever appears; launching again just hands off to the windowless instance.
`~/.local/share/t3code-desktop/userdata/logs/server-child.log` shows the
backend restart-looping every ~30 s on `NodePtyModuleLoadError: Failed to load
node-pty for linux-x64`, with a misleading `Cannot find module
'./prebuilds/linux-x64/pty.node'` — the file is there; `ldd` on it says
`libstdc++.so.6 => not found`.

node-pty 1.2.0-beta ships a linux-x64 prebuild, so the package's
`pnpm rebuild` no longer builds `pty.node` from source, and nixpkgs sets
`dontPatchELF` on the vendored tree. `t3 serve` is unaffected (nodejs links
libstdc++ itself, so the dlopen resolves); the app's backend runs under
Electron, which does not. That is also why the feature test loads node-pty with
`ELECTRON_RUN_AS_NODE=1 electron`, not `node` — the `node` version passes on the
broken package. Fix: `t3codeUnwrappedFor` adds a libstdc++ rpath to just that
file. Drop it once nixpkgs patches the prebuild (the assertion will tell).

## 2026-10-16 — pinned to 0.1.0 (Orchestrator V2) ahead of nixpkgs

nixpkgs (even master) was still on 0.0.45 the day after upstream shipped the
first stable V2, so `t3code.nix` pins `version` + `srcHash` + `pnpmDepsHash`
over nixpkgs' recipe instead of waiting for the r-ryantm bump. Things V2
changes that matter here:

- **V1 and V2 do not talk to each other** — the side that is older refuses the
  connection. The unit and the app come from the same derivation, so they move
  together; the phone needs the 2.0 store app (or the web app at
  app.t3.codes, which follows the server).
- **The first V2 start copies the database one way.** The V1 copy stays put, so
  rolling back to an older generation brings back the pre-update threads, not
  the ones made since.
- **Minimum provider versions:** Claude Code 2.1.280+ (llm-agents was on
  2.1.292). Settings → Providers flags a too-old one.
- **New Chromium profile:** Electron's userData moved from `~/.config/t3code`
  to `~/.config/t3code-v2`. Upstream imports the V1 Local Storage (drafts,
  layout, theme) once and leaves a `v1-local-storage-imported` marker, but the
  safeStorage key is not carried over (next section).

## 2026-10-16 — the paired unit vanished from the app after 0.1.0

Right after the switch, `desktopNixos` was gone from Settings → Connections.
The app showed only its own local environment. The pairing itself was fine:
`t3 auth session list` still had the `t3code-desktop | Electron` session, valid
until 2026-11-08. The app could no longer read it. Every launch logged this in
`~/.local/share/t3code-desktop/userdata/logs/desktop.trace.ndjson`:

```
DesktopConnectionCatalogStoreProtectionError: Desktop connection catalog
  protection failed during decrypt-catalog at …/connection-catalog.json
  [cause]: ElectronSafeStorageDecryptError … safeStorage.decryptString
```

The catalog (saved environments plus their bearer credentials) is encrypted
with Electron `safeStorage`. On Linux the key lives in the keyring under the
app's **`productName`**, and upstream derives that from the release stage.
0.0.44 shipped `"productName": "T3 Code (Alpha)"`, 0.1.0 ships
`"T3 Code (Beta)"`. The first 0.1.0 launch found no key under the new name,
generated one, and the catalog (`v11` prefix: libsecret key) became
unreadable:

```console
$ secret-tool search --all xdg:schema chrome_libsecret_os_crypt_password_v2
attribute.application = T3 Code (Alpha)   created 2026-10-11   ← the catalog's key
attribute.application = T3 Code (Beta)    created 2026-10-16 19:35:50 UTC ← first 0.1.0 launch
```

Upstream's own `app.setName("T3 Code Beta")` runs later and does not affect
the keyring entry. Only package.json's `productName` does, because Electron
reads it before the main script runs.

**Fix:** `t3codeUnwrappedFor` rewrites the installed
`apps/desktop/package.json` so `productName` is always `keyringName`
(`"T3 Code (Alpha)"`, the name the existing key was made under). The
existing catalog decrypts again with no re-pairing, and later stage renames
(Beta → stable, …) no longer touch the key. The feature test asserts the pinned
name. `productName` is read by nothing else that matters here: the bundle
never reads it, and upstream sets userData, the about-panel name and the
app_id (`app.setDesktopName()` + `--class`) explicitly. The orphaned
`T3 Code (Beta)` keyring entry is harmless.

Decrypting the catalog by hand with the Alpha key (PBKDF2-SHA1 of the keyring
secret, salt `saltysalt`, 1 iteration, AES-128-CBC, IV of 16 spaces) showed
the `desktopNixos` profile intact. It also showed the unit's environmentId in
`disabledEnvironmentIds`. The V1 app wrote that at 21:35:37, right when the unit
came back as V2. So after the fix the environment returns switched off and
needs one toggle in Settings → Connections.

If the environment disappears again after a bump, check the log line above
first. If it is a decrypt error and `productName` is still pinned, upstream
changed where the key name comes from. Compare the newest keyring entry's
`application` with `keyringName`.

## 2026-10-16 — one environment instead of two, named "Desktop"

Once the unit was back, the environment picker listed it twice:
`desktopNixos · http://127.0.0.1:3773/` (the unit) and
`desktopNixos · http://127.0.0.1:3799/` (the app's own backend, see *The
client* above). V2 lets the app run without that backend. Its
`desktop-settings.json` has `localEnvironmentEnabled` (default `true`), and with
`false` the bootstrap logs `bootstrap skipping local environment (disabled in
settings)`. No server is spawned, and the `t3code://` protocol serves the UI
from the bundled assets instead of proxying to a backend. There is no flag or
variable for it, only that file. The app also writes window bounds and the
update channel there, so `desktopSettingsFor` sets just that one key with jq
before every launch, and leaves a file jq cannot parse alone.

What turning it off costs: `desktop:pick-folder` and the project-favicon picker
return `null` without a local environment, so "Add project" cannot open the
native folder dialog. Adding a project to the unit goes through the server's
filesystem RPC, which needs a V2 pairing (`filesystem:read`). Preview does not
depend on the local environment.

The name comes from the server, not the app. `resolveServerEnvironmentLabel`
tries `PRETTY_HOSTNAME` from `/etc/machine-info`, then `hostnamectl --pretty`,
then `os.hostname()`. Neither of the first two existed here, hence
`desktopNixos`. `hosts/desktop-nixos/pretty-hostname.nix` sets it through
`environment.etc` (NixOS points systemd-hostnamed at `/etc/static/machine-info`
and has no option of its own). The server reads it at startup, so it takes a
restart of `t3code.service`. The app's connection catalog stores the label
from the moment of pairing (`"label": "desktopNixos"` in the profile), so
re-pair after a rename. The icon is a server setting (`environmentIcon` in
`~/.t3/userdata/settings.json`, here detected as `server`), changeable in
Settings → Connections.

## 2026-10-19 — the server's browser needs Chrome's libraries in nix-ld

0.1.0 moved preview off the Electron client: the **server** now runs browser
tabs and `html_render` in a shared headless Chrome it downloads to
`~/.t3/tools/chrome-headless-shell/linux64/<version>/` (upstream
`apps/server/src/preview/PreviewBrowserHost.ts`). On this host every
`preview_open` failed with *"This host is missing libraries T3's browser needs
(libglib-2.0.so.0, … 22 in all). Run `sudo env "PATH=$PATH" t3 browser setup`"*.
That command apt-installs Chrome's Debian deps and writes an AppArmor profile —
neither applies to NixOS. Don't run it.

The binary is foreign, so it loads through nix-ld; the fix is those libraries in
`programs.nix-ld.libraries` (feature `t3code-server`, the list mirrors
upstream's `DEBIAN_PACKAGES`). Measured before changing anything: with the 22
libraries on `NIX_LD_LIBRARY_PATH`, `chrome-headless-shell --version` answers
and a sandboxed `--headless --dump-dom` renders a page, so the sandbox needs
nothing more (no `T3CODE_SERVER_BROWSER_SANDBOX=0`).

`ldd` keeps reporting all 22 as `not found` even then — it goes through Nix's
glibc loader and never consults nix-ld. T3 knows: it decides with the browser's
own `--version` and only lists ldd's misses after that fails. So don't trust
`ldd` here; run the binary.

The running unit needs no restart: its `NIX_LD_LIBRARY_PATH` is the fixed
`/run/current-system/sw/share/nix-ld/lib`, which the switch refills.

## 2026-10-21 — why the preview browser feels worse than a real browser

Complaints: blurry, logins don't stick, no extensions (Bitwarden), Google says
"This browser or app may not be secure". There are two browsers behind the one
Browser panel, and which one a tab gets decides all four:

| tab opened by…                 | runs in                                                          | drawn as                  | storage                                              |
| ------------------------------ | ---------------------------------------------------------------- | ------------------------- | ---------------------------------------------------- |
| you, in the desktop app        | the app's own Electron `<webview>` (`runtime: "desktop"`)        | native, sharp             | `~/.config/t3code-v2/Partitions/t3code-preview-*`    |
| an agent (`preview_open`)      | the unit's `chrome-headless-shell` (`runtime: "server"`)         | JPEG screencast stream    | `~/.t3/userdata/server-browser/profiles/<profile>`   |

The desktop app renders a server tab natively only for a server it spawned
itself (`DesktopBrowserChannel` needs the bootstrap fds). The unit is not one, so
every agent tab is streamed. `previewRuntimeFor` (upstream #17316) sends the
tabs *you* open on a non-primary environment to the desktop instead, and a
streamed tab has **More → Open on this computer**. Agents can't see a desktop
tab.

Measured on this host:

- **Quality.** The stream is JPEG at the server's `DEFAULT_QUALITY = 70`, and
  50 at half resolution while scrolling. The client never sends `quality`
  (upstream #16578, closed with #17316 and no setting). `t3codeUnwrappedFor`
  patches both up (`streamQuality`, `streamMotionQuality`). Rendering is 2×, so
  the gain is ringing around text, not resolution.
- **Google sign-in.** In the server browser the page sees `plugins.length = 0`,
  no `window.chrome`, a SwiftShader WebGL renderer and `screen` equal to the
  viewport, which are all headless tells. Upstream spoofs the UA and client
  hints (#16963), but Google's account check still rejects it (#20867, closed
  as out of scope). Sign in from a desktop tab instead. Upstream says #16939
  fixed sign-in there; not measured on this host.
- **State.** Logins live in four places that never share: the server browser's
  profile, and three Electron profiles from three app generations:
  `~/.config/t3code` (until 08-25), `T3 Code (Alpha)` (until 10-15) and
  `t3code-v2` (since V2, 10-16). V2 moved the profile on purpose
  (`DesktopUserData.ts`) and carried over only localStorage, not partitions,
  so every login made before 10-16 stayed behind in the Alpha profile. A login
  in a desktop tab is invisible to agent tabs and the other way round.
- **Extensions.** Neither browser can have them: upstream never calls
  `session.loadExtension` and the headless shell has no extension support.
  Even a full Chromium swapped in for the shell (Ideas #17465, the
  `Tarsow/t3-headed-browser` shim) would stream page pixels only, so a
  Bitwarden popup would never appear. Use **Open in browser** for sites that
  need the vault. *(Superseded for the server browser on 2026-10-24, below.)*

## 2026-10-24 — the server browser is a headed Google Chrome

Upstream still hardcodes `headless: true` and the downloaded shell (`main` at
71df573f; #20867 closed without a fix), so `server-browser-headed.patch` adds
one switch: with `T3CODE_SERVER_BROWSER_EXECUTABLE` set, `ServerBrowserContexts`
launches that browser **headed** instead of the shell. The unit sets it to
nixpkgs' `google-chrome`, on `:99`, a virtual Xvfb display from its own
`t3code-display` unit (passed as `T3CODE_SERVER_BROWSER_DISPLAY`, see below), so
no window lands on the niri session. Unset, the
patched server behaves exactly like upstream.

Measured with T3's own Playwright (1.60) and launch options, same IP:

| browser                                   | `webdriver` | `window.chrome` | plugins | Google sign-in after the email   |
| ----------------------------------------- | ----------- | --------------- | ------- | -------------------------------- |
| `chrome-headless-shell` 154, as T3 runs it | false       | undefined       | 0       | `/v3/signin/rejected`            |
| `google-chrome` 154, headed on Xvfb        | false       | object          | 5       | password step                    |

What the patch has to do besides `headless: false`:

- **Keep the first window.** `contextFor` closes every page a persistent
  context starts with. A headless shell survives that; a headed browser quits
  with its last window and the next `newPage` dies with *"Target page, context
  or browser has been closed"* (the shim's docs measured the same). In headed
  mode it keeps the first `about:blank` window; it is never a T3 tab.
- **Drop Playwright's anti-person defaults.** Playwright adds
  `--disable-extensions`, `--disable-component-extensions-with-background-pages`,
  `--disable-sync`, `--disable-background-networking` and
  `--disable-component-update`; with them Chrome Sync is off and a policy
  extension never installs. Headed mode ignores those five (plus
  `--enable-automation`, as upstream). `--password-store=basic` stays, so
  cookies are encrypted with Chrome's fixed key and need no keyring.
- **Nothing for identity.** `presentAsChrome` only rewrites a `HeadlessChrome`
  user agent; the real Chrome's doesn't match, so it is left alone.

Why Google Chrome and not Chromium or Brave: Chromium builds have no Chrome Sync
(Google withdrew the API keys), and sync is what lets a login made once follow
the profile. The version is also nixpkgs' and pinned by the flake, not a second
download; at the switch both were 154.0.8037.x, so the shell's existing profile
(`~/.t3/userdata/server-browser/profiles/default`) opened unchanged.

Logins persist in that profile. Agent tabs (`preview_open`) use the client's
default profile too, so they see the same logins; only incognito tabs and agent
tabs opened without a client-reported profile get throwaway contexts.

**Bitwarden** is force-installed by Chrome managed policy
(`/etc/opt/chrome/policies/managed/t3code-server.json`,
`ExtensionInstallForcelist`), from `nixos.t3code-server`. Chrome ≥137 ignores
`--load-extension` in branded builds, so policy is the only declarative route.
Measured after the switch: installed on the first launch (`location: 7`,
external policy download, no `disable_reasons`).

A policy-installed extension also needs `DeveloperToolsAvailability = 1` in the
same file. The panel attaches its own CDP session to stream a tab, and Chrome's
default (0) refuses DevTools on the pages of policy-installed extensions. The
agent's tab rendered, because its session was attached while the page was still
`about:blank`, but the human's panel showed *"Browser connection was refused"*,
and the unit logged `Target.attachToTarget: Not allowed`. Chrome reads policy at
startup: after changing it, kill the server's Chrome (main process, `pgrep -f
'share/google/chrome/chrome --simulate-outdated.*\.t3'`), and T3 relaunches it on
the next tab.

Its popup is browser chrome, which the stream never shows, so it is opened as a
page: `chrome-extension://nngceckbapebfimnlniiiahkandclblb/popup/index.html` in
the panel's address bar (or `preview_open`). Upstream's `normalizePreviewUrl`
(`packages/shared/src/preview.ts`) allowed only http(s); the same patch adds
`chrome-extension:`. Log in to the vault there once; the inline autofill menu on
login forms appears only after that. Its first screen asks to become the default
password manager through a browser permission prompt the stream can't show:
skip it.

Verified end to end on 2026-10-24: after logging in to the vault in that tab
(new-device code by email), focusing `#login_field` on github.com/login shows
Bitwarden's field icon and its inline menu with the saved login, both in the
agent's snapshot and in the human's panel (checked with `grim`).

**The window must be pinned to Xvfb.** The first deploy set `DISPLAY=:99` in
the unit, and Chrome still opened its windows on the niri session (a
"Bitwarden - Google Chrome" window on workspace 4): its environment had
`DISPLAY=:0` and `WAYLAND_DISPLAY=wayland-1`. The server merges the login
shell's environment into `process.env` at startup, so the unit's `DISPLAY` is
overwritten. The patch reads the display from its own variable,
`T3CODE_SERVER_BROWSER_DISPLAY`, which no shell sets, drops `WAYLAND_DISPLAY`
from the browser's environment, and passes `--ozone-platform=x11`. Verified:
`xwininfo -root -tree` on `:99` lists the window; `niri msg windows` lists no
Chrome.

**Google sign-in in the panel** (`test@gmail.com`): no `/rejected`. After
several tries of the same address from this IP it asked for a text CAPTCHA
instead of the password, which is a normal challenge for a person to solve.

## 2026-10-24 — "Open in VS Code" opened over SSH into this same machine

The app reaches the unit as a saved (bearer) environment paired at
`http://127.0.0.1:3773`. Upstream's `resolveRemoteOpenState`
(`apps/web/src/remoteOpen.ts`) checks for loopback only on the *primary*
environment, the backend the app spawns itself. A saved one is always "remote", so
"Open" built `vscode://vscode-remote/ssh-remote+<MagicDNS name>/<path>` and
VS Code connected over SSH to the host it was running on.

The opposite, `local-exec`, would be wrong too: it asks the **server** to spawn
the editor, and the unit has no session display (now `DISPLAY=:99`, so VS Code
would open invisibly on Xvfb). `open-local-editor.patch` adds a third case: in
the desktop app, a bearer environment paired on loopback resolves to the
`this-machine` link host. The app then opens `<scheme>://file/<path>`
(`buildLocalOpenUrl`, VS Code and its forks, Zed) through `shell.openExternal`,
whose allowlist (`ElectronShell.ts`) now also lets those plain local links
through. `xdg-open` hands `vscode://` to `code-url-handler.desktop`. The "Opens
over SSH" hint is hidden for that case.

## 2026-10-25 — extension windows (Bitwarden's passkey prompt) open as tabs

Bitwarden opens its passkey prompt ("Log in with passkey"), its "pop out"
window and its login helpers with `chrome.windows.create`. Such a window has no
opener page, so no tab's Playwright `popup` event fires and upstream never
turns it into a tab: it stayed a bare window on the virtual display (`:99`),
invisible and unclickable from the panel. The GitHub passkey sign-in got stuck
there until it was clicked with `xdotool`.

`server-browser-extension-windows.patch` listens to the context's `page` event.
A page that commits a non-blank URL, is not already a tab, has no opener, and
has a real window (`Browser.getWindowForTarget` fails for an extension's
offscreen document) is adopted like a popup:

- It goes beside the tab a person is watching in that context. It is always the
  person's tab, so it is switched to for every viewer, even when an agent opened
  the tab behind it.
- If no tab is left, it goes to the thread that last opened one. Bitwarden's
  "pop out" closes the very tab it was clicked in.

Pages the server itself opens navigate only after they are tabs, so they are
never adopted twice.

Verified live: "Pop out to a new window" in a Bitwarden tab produced a panel
tab at `popup/index.html?uilocation=popout`, both with another tab open and
with the clicked tab being the only one.

## Updating

Two ways, depending on whether nixpkgs has caught up:

- **nixpkgs has the version you want:** drop `version` / `srcHash` /
  `pnpmDepsHash` and their `overrideAttrs` lines from `t3codeUnwrappedFor`, then
  `nix flake update nixpkgs`.
- **nixpkgs lags:** bump `version`, set `srcHash` from
  `nix run nixpkgs#nix-prefetch-github -- pingdotgg t3code --rev v<version>`,
  set `pnpmDepsHash` to a fake hash and build once — the mismatch prints the
  real one. Check that `native/resource-monitor/Cargo.lock` did not change
  between the tags (`gh api repos/pingdotgg/t3code/contents/native/resource-monitor/Cargo.lock?ref=<tag> --jq .sha`);
  if it did, nixpkgs' `cargoHash` for the sidecar is stale too.

Track stable tags (`gh release list -R pingdotgg/t3code --exclude-pre-releases`),
not the several-times-a-day `*-nightly` / `*-preview` prereleases. The node-pty
rpath patch is still needed on the pinned nixpkgs; nixpkgs master now carries
the same `postFixup`, so it can go once the pin moves past that. The
`productName` pin (`keyringName`) stays regardless of how the version is
sourced. It is not a version workaround: dropping it orphans the saved
environments again.
