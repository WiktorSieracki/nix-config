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

### The desktop app is not a client of this server — use a browser

**2026-08-29, measured.** The Electron app always spawns *its own* backend; it
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

## The client: a chromeless browser window

Feature `t3code` is a launcher entry, not an app. `t3code-web` runs the
canonical chromium browser (`meta.programs.chromium-browser`) as:

```bash
brave --app=http://localhost:3773 --user-data-dir="$XDG_DATA_HOME/t3code-web"
```

- `--app=` is what removes the tab strip and address bar. Firefox has no
  equivalent since `--ssb` was dropped, which is why this uses the chromium
  browser and not `meta.programs.browser`.
- The dedicated `--user-data-dir` gives the window its own cookie jar (so it
  stays paired independently of the browsing profile) and its own process (so it
  launches and closes on its own instead of as a window of a running browser).
- **`--class` does nothing here.** Chromium ignores it for `--app` windows on
  Wayland and derives the app_id from the URL plus the profile directory.
  Measured on 2026-08-29:

  ```console
  $ niri msg -j windows      # after launching t3code-web
  'brave-localhost__-Default' | T3 Code (Alpha)
  ```

  So `StartupWMClass` in the desktop entry has to be that string, not a name of
  our choosing. Re-measure with the same command if the URL changes.
- **Pair it on the same origin it opens.** The session is a cookie, and cookies
  are scoped per host, so `127.0.0.1` and `localhost` are two different logins.
  `t3 pair` prints `http://127.0.0.1:3773/pair#token=…` while the launcher opens
  `http://localhost:3773` — rewrite the host before feeding it to this profile:

  ```bash
  brave --user-data-dir="$XDG_DATA_HOME/t3code-web" \
        "http://localhost:3773/pair#token=$(t3 pair --label t3code-web | \
          grep -oE 'token=[A-Z0-9]+' | cut -d= -f2)"
  ```

  A chromeless window has no address bar, so the token has to arrive this way —
  through a normal window on the *same* `--user-data-dir`. Once paired the
  cookie lives in the profile and `t3code-web` opens straight into the app.
- `t3 auth session list` is a poor liveness check: `last connected` does not
  refresh on every websocket reconnect. To see whether a client is really
  attached, look at the sockets instead — `ss -tnp state established | grep
  :3773` names the browser process holding them.
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

## Updating

Bump nixpkgs (`nix flake update nixpkgs`). There is nothing version-shaped left
in this file. `passthru.updateScript` upstream tracks GitHub releases, so the
nixpkgs attr follows stable tags, not the several-times-a-day `*-nightly`
prereleases.
