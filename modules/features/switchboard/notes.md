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
