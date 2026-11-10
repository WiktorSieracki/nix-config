# switchboard — feature notes

Non-executable knowledge about the `switchboard` feature. *Reproducible* bugs →
assertions in the feature test (`switchboard.nix`), not here. Dated entries, format
`Symptom → Cause → Fix`.

## 2026-07-03 — a feature test with `nix` in the `requires` closure vs read-only `nixpkgs.config`

**Symptom:** the first feature test failed at eval: "The option
`nodes.machine.nixpkgs.config` is defined multiple times … nixpkgs.config is set to
read-only". Switchboard is the first feature whose `requires` pulls `nix` into the
feature-test VM.

**Cause:** the `nix` feature sets `nixpkgs.config.allowUnfree = true`, while
`nixosTest` receives ready-made `pkgs` and marks the node's `nixpkgs.config` as
read-only — any extra definition is a conflict.

**Fix:** the same stub the `nix` feature's own feature test uses:
`extraNixosModules = [ ({lib, ...}: {nixpkgs.config = lib.mkForce {allowUnfree = true;};}) ]`.
Applies to EVERY future feature test whose `requires` closure contains `nix`.

## 2026-07-03 — `app.suspend()` "swallows" a command's output after it finishes

> **[2026-07-04]** This entry concerns the retired Python/Textual implementation.
> The same problem (and an analogous fix) exists in the Go version — see the
> "`tea.ExecProcess` returns to the alternate screen…" entry below.

**Symptom:** after `nh os test` launched from the TUI, the output (including
nvd-diff) disappears in a split second — it can't be read.

**Cause:** Textual draws in the terminal's alternate screen; leaving the
`App.suspend()` context immediately returns to the alternate screen and hides
everything the command printed.

**Fix:** after `subprocess.call(...)` and before the end of `suspend()`, a blocking
`input("… press Enter to return")` — the user reads the output and returns to the
TUI themselves. `EOFError` must be caught (no stdin ≠ a crash).

## 2026-07-03 — SelectionList (Textual 8.x): keep state in the model, not the widget

> **[2026-07-04]** This entry concerns the retired Python/Textual implementation.
> The "state in the model, not the widget" principle carried into the Go version
> naturally: bubbletea (the Elm architecture) has no stateful widgets — the source
> of truth is the `enabled` list in the model, and checkboxes render from it on
> every View().

**Symptom:** with a live filter + auto-pulling of dependencies, the checkboxes
"lose" state; programmatic `select()/deselect()` fires further `SelectionToggled`
and it's easy to hit an event loop.

**Cause:** the filter requires rebuilding the option list (a subset is visible), so
the widget can't be the source of truth; the select/deselect API differs between
Textual versions and emits events like a user toggle.

**Fix:** the source of truth is the `enabled` list in the screen; every change →
`clear_options()` + `add_option(...)` with `initial_state` from the model, under a
`_rebuilding` flag that ignores events in the meantime. Blocking a deselect = a
refusal in the model + a rebuild (the checkbox comes back by itself).

## 2026-07-04 — rewrite in Go + bubbletea (the Python/Textual version retired)

The domain logic carried over 1:1 (the `requires` closure, deselect blocking,
write-order reconciliation, the flake.lock diff) — now in pure functions
(`model.go`, `lock.go`, `grid.go`) under unit tests `go test ./...`. The Python
implementation stays in git history (last commit `9c3b3e4`) as a reference.

## 2026-07-04 — `buildGoModule` with `src = ./.` in the feature folder

**Symptom:** none — but two non-obvious consequences of keeping the Go sources
directly in the feature folder.

**Cause/knowledge:** (1) `src = ./.` also covers `switchboard.nix` and `notes.md`,
so *every* feature-notes entry rebuilds the package — acceptable (the build takes
seconds), but don't be surprised by rebuilds. (2) `buildGoModule` runs
`go test ./...` in checkPhase — the unit tests must be hermetic (no network/git),
but in return every system build is gated by tests for free.

**Fix (vendorHash workflow):** put in `lib.fakeHash` (or any `sha256-AAAA…=`), build
the package via
`nix build --impure --expr 'let flake = builtins.getFlake (toString /path/to/repo); pkgs = flake.inputs.nixpkgs.legacyPackages.x86_64-linux; in pkgs.buildGoModule { … }'`
and copy the hash from the `got: sha256-…` message. Note: new `.go` files must be
`git add`ed *before* that build (the flake only sees tracked files).

## 2026-07-04 — `tea.ExecProcess` returns to the alternate screen and hides output

**Symptom:** the same as in Textual: after `nh os test`/`nix build --dry-run`
launched from the TUI, the output disappears right after the command finishes —
bubbletea returns to the alternate screen.

**Cause:** `tea.ExecProcess` hands the terminal to the process, but after it exits
the program immediately re-renders the TUI in the alternate screen.

**Fix:** wrap the command in `sh -c` with a script: `cmd; rc=$?; printf '…press
Enter…'; read -r _ || true; exit $rc`. `read` gets stdin = a real TTY (since it's
still ExecProcess), `|| true` guards against EOF (no stdin ≠ a crash), and
`exit $rc` propagates the command's exit code to the callback (`*exec.ExitError`).

## 2026-07-04 — `go vet`/`go test` outside Nix: no `gcc` on PATH

**Symptom:** `nix shell nixpkgs#go -c go test ./...` fails on
`cgo: C compiler "gcc" not found` (building `runtime/cgo`).

**Cause:** a bare `nixpkgs#go` doesn't pull a C toolchain, and cgo is enabled by
default.

**Fix:** `CGO_ENABLED=0` — the project is pure-Go. In `buildGoModule` the problem
doesn't occur (stdenv has cc).

## 2026-07-06 — migration to `{system, users}` (ADR 0004)

**Context:** `features.json` stopped being a flat list — it's now
`{"system": [...], "users": {"<login>": [...]}}`. `HostSpec` (model.go) replaces the
bare `[]string`; `Sections()`/`Get`/`Set`/`Clone`/`SpecEqual` operate on the whole
spec, and the UI got section tabs (`tab`/`[`/`]`) — each edited independently, and
`enable()` computes the `requires` closure against `system ∪ the current section`
(the `satisfiers()` method), not the whole file.

**Pitfall to remember:** `enable()` checks already-present dependencies via
`contains(m.enabled(), dep)` — without that, auto-pulling could add a duplicate of a
feature that's satisfied by `system` but not by the user's section itself. The unit
test doesn't catch it (too few scenarios in `model_test.go`) — if something breaks
here, it shows up as a duplicate in `features.json` after saving, not as a crash.

## 2026-07-04 — `--help` with exit 0 without a TTY: `flag.ExitOnError`

The feature test needs `switchboard --help` to exit 0 in a headless VM. The `flag`
package with `flag.ExitOnError` does this out of the box: `-h`/`--help` → usage +
`os.Exit(0)` (other parse errors → exit 2). Don't change it to ContinueOnError
without carrying that semantics over.

## 2026-11-10 — `switchboard web`: the same lists in a browser

**Context:** the TUI shows one host at a time. `switchboard web`
serves a page with every host side by side (a lamp per feature and host), the
`requires` graph, and the same save → test/switch → commit finale. One binary,
no new dependency: the page (`web/`) is embedded with `go:embed` and written
without a build step or a framework, so `buildGoModule` stays as it was.

**The rules moved, they were not copied.** `rules.go` holds the loader's
validation mirrored in Go (`ValidateSpec`), the toggle (`Toggle`) and the diff;
the TUI and the HTTP API both call it. The page decides nothing: a click is a
round trip to `/api/toggle` with the page's draft, and the answer is the next
draft. The server keeps no draft — reloading the page drops unsaved edits (the
page warns before it unloads).

**What changed for the TUI by sharing them:**
- a `conflicts` pair is refused (the TUI did not know the field, so it wrote
  lists the loader rejected at the next rebuild);
- the home screen lists every host with a `features.json` — `vpsNixos` was
  missing from the hardcoded pair;
- a save replaces the file in one step (a sibling written in full, then renamed
  over it).

## 2026-11-11 — back to one flat list per host

**Context:** `features.json` is a JSON array again — it was
`{"system": [...], "users": {"<login>": [...]}}` since 2026-07-06 (entry above).
With one account per host the split carried no information: the loader can tell
by itself that a home-manager part goes to the account and everything else to
the machine. It still had to be decided by hand on every toggle, in both UIs,
and it was never clear which list a feature belonged on. The work account — the
reason for the split — went in the same change.

**What it means here:** `HostSpec`, sections, the `[s]` marker and the
"home-manager feature in `system`" refusal are gone; a host's features are a
`[]string` end to end, the commit subject is `switchboard: <host> +a -b` again,
and `ValidateFeatures` follows the loader's new wording. Entries above that talk
about sections describe the retired model.

**How it was shown to change nothing:** the system derivation of every host
(desktop, laptop, vps, iso, vm) was identical before and after the flattening —
compared with `system.configurationRevision` pinned, since that one input moves
with every tree state.

**Pitfall:** binary and repo must agree on the shape. An older `switchboard`
against a flat list, or this one against a checkout from before the change,
stops with "it has to be a JSON array of feature names" rather than guessing.

## 2026-11-10 — why the web server refuses the way it does

**Symptom:** none yet — this is the reasoning to keep when touching `guard()`.

**Cause:** the server can rewrite the config and run `nh os switch`, and it
listens on loopback — which every account on the machine and every page open in
the browser can reach. Four separate attacks, four checks (each has a test in
`web_test.go`/`peer_test.go`, and the feature test repeats the first three
against the real binary):
1. *Another local user* — an account without sudo (a service user, a second
   login) must not get one through us; its `curl` sends the right `Host`, no
   `Origin`, and could read the token off the page.
   So every connection is attributed first: the uid owning the client socket,
   read from `/proc/net/tcp{,6}` (TCP has no `SO_PEERCRED`), must be the uid
   that started the server (`peer.go`). A connection that cannot be attributed
   is refused too.
2. *DNS rebinding* — a page points its own hostname at 127.0.0.1 and becomes
   "same origin". It cannot fake the `Host` header: anything but the bound
   address or `localhost`, on our port, is a 403.
3. *Cross-site writes* — a form or `fetch` from another origin. Non-GET requests
   with a foreign `Origin`, or `Sec-Fetch-Site` other than `same-origin`, are a
   403. (Cookies would not do instead: they are not scoped by port, so any other
   server on 127.0.0.1 would be handed them.)
4. *Blind requests* — every `/api/*` call except `/api/ping` needs the per-run
   token that only the served page carries. Only such calls reset the idle
   clock, so a site looping over `/favicon.svg` cannot keep the server alive.

**Fix / rule:** there is no login, so `--addr` must be loopback — binding
elsewhere is refused at startup. To use it from another machine, forward the
port: `ssh -L 7391:127.0.0.1:7391 <host>`, then open `http://localhost:7391`.

## 2026-11-10 — a page under `default-src 'self'` ignores inline styles

**Symptom:** an element built with a `style="…"` attribute (or
`setAttribute('style', …)`) renders unstyled, with only a console warning.

**Cause:** the Content-Security-Policy the server sends has no
`'unsafe-inline'`, on purpose.

**Fix:** state goes into classes and `data-state` attributes that `style.css`
keys on; for a computed value use the CSSOM (`el.style.setProperty`), which the
policy allows. SVG geometry is attributes, not style, so the graph is unaffected.

## 2026-11-10 — commands run from the web UI have no terminal

**Symptom/knowledge:** `nh os test/switch` started by the page gets no TTY.

**Consequences:**
- nix-output-monitor would redraw its build tree into the log, so the web jobs
  pass `--no-nom`; the output is cleaned line by line (ANSI stripped,
  carriage-return redraws reduced to the last state).
- `sudo` cannot prompt. These hosts have `wheelNeedsPassword = false`; on a
  host that asks for a password the job fails with sudo's "a terminal is
  required" in the console — use the TUI there.
- *Stop* exists for the build check only. It signals the job's process group,
  and for `nh os test/switch` that group contains `sudo`, which relays the
  signal to `switch-to-configuration` — a half-applied activation. So the
  server refuses to stop those, and on Ctrl+C/SIGTERM it waits for a running
  activation before exiting (closing the pipe the job writes to would kill it
  just the same). A second Ctrl+C exits anyway.
- test/switch are offered for this machine's own host only (the server checks,
  not just the page); every other host gets a `nix build --dry-run`.

## 2026-11-10 — the web UI's lifetime: one instance, gone when the tabs are

**Knowledge:** `switchboard web` binds `127.0.0.1:7391`. A second invocation
(the launcher entry clicked twice) finds the first through `/api/ping` and only
opens the browser at it. Started from the launcher there is no terminal to
Ctrl+C, so the server exits by itself after `--idle-timeout` (30 min) without a
request; an open page asks for `/api/state` every 20 s — which is also how
edits made elsewhere (the TUI, an editor, git) show up — and a running job
counts as activity. Browsers throttle background tabs to about one timer a
minute, still far inside the timeout.

**Pitfall:** the assets are compiled in. After editing `web/*`, rebuild
(`CGO_ENABLED=0 go build`) and restart — a browser reload alone serves the old
page from the old binary.
