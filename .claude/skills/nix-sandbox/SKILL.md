---
name: nix-sandbox
description: Use when verifying that a feature of this nix-config actually works at runtime — not just that it evaluates or that its binary exists. Boots a live throwaway VM on the right monitor, installs the single feature into it, drives the real graphical session (niri msg, grim, ydotool), and reports back. Triggers: "sprawdź czy X działa", "przetestuj feature X", "/nix-sandbox", "odpal to w vmce", verifying a new or changed feature before switching the real host.
---

# Live sandbox (Tier-1-live)

A feature test proves *a binary is on PATH and a unit started*. That is not the
same claim as *the feature works*. Every runtime bug this repo has hit — noctalia
IPC drifting from niri's config, `load-config-file` reloading a stale store path,
ghostty rendering nothing under virgl — passes its feature test and fails a human.
This skill closes that gap: a real VM, a real session, a real click.

**The rule that makes it worth anything: you may only report "działa" about
something you made fail first.**

## The loop

Work one feature at a time. `<f>` is the feature name.

### 1. Boot the red state

```bash
nix run .#sandbox -- up <f>
```

Boots `sandbox-base`: core + desktop + sshd + the `tester` account, and **not**
the feature. The window opens on the right monitor, unfocused — the user watches,
you never touch their keyboard.

Refused for `runtimeUntestable` features (no GPU, no tablet, no real SOPS key).
That refusal is correct; do not work around it. Say the feature cannot be
verified this way and why.

### 2. Write the check — before the implementation

Create `modules/features/<path>/<f>/check.sh` (or `<f>.check.sh` beside a
single-file feature). Plain `sh`, runs *inside the guest* with the session
environment already resolved. One line per assertion, exit non-zero on failure:

```sh
#!/bin/sh
# What "<f> works" means, executably.
fail=0
ok()   { echo "ok: $1"; }
bad()  { echo "fail: $1" >&2; fail=1; }

niri msg -j windows | jq -e 'any(.[]; .app_id == "com.mitchellh.ghostty")' >/dev/null \
  && ok "ghostty window is on screen" || bad "no ghostty window"

exit $fail
```

Available in the guest: `niri msg` (`-j` for JSON — the real window tree),
`grim`, `wtype`, `ydotool`, `jq`, `systemctl`, `journalctl`.

**Wait for things, never sleep blindly.** llvmpipe is slow; a bare `sleep 1`
buys a flaky check, and a flaky check teaches you to ignore red.

### 3. Prove the check is not vacuous

```bash
nix run .#sandbox -- red <f>
```

Runs the check on the base, where the feature is absent. It **must fail**. If it
passes, the runner stops you: the check asserts something that was true anyway,
so every later green would be meaningless. Rewrite it.

### 4. Implement, then install into the running VM

Implement the feature in the repo. `git add` new files — flakes do not see
untracked ones.

```bash
nix run .#sandbox -- deploy <f>
```

Builds locally, switches the **running** VM to `sandbox-<f>`, and restarts the
graphical session so it matches the new generation. That restart is load-bearing:
without it niri keeps the previous generation's config (its wrapper pins
`NIRI_CONFIG` to a store path) and you will debug a keybind that was never loaded.
The session comes back empty — assertions must open what they need.

### 5. Go green, then look

```bash
nix run .#sandbox -- check <f>
nix run .#sandbox -- shot after-deploy   # prints a host path
```

Read the screenshot. Actually read it. `niri msg` says a window exists; only the
picture says it is not a black rectangle, an error dialog, or a login screen.

Drive the session for anything a bare check cannot reach:

```bash
nix run .#sandbox -- exec -- niri msg -j windows
nix run .#sandbox -- exec -- niri msg action focus-column-right
nix run .#sandbox -- exec -- journalctl --user -b --no-pager -n 50
```

**Know what the sandbox can and cannot drive today** (see
`modules/hosts/sandbox/notes.md`, 2026-09-19):

- *Works:* reading the window tree, `grim`, any `niri msg action`, and
  client-level typing with `wtype`.
- *Does not work yet:* device-level input — `ydotool` and QMP `send-key` reach
  nothing, because the guest's graphical session has no seat and therefore no
  input-device ACLs.
- *Consequence:* you can verify that **the action behind a keybind** works. You
  cannot yet verify that **the keybind itself** is wired. Do not report a
  keybind as working on the strength of its action — say which one you tested.

Before a session exists (GRUB, boot, the greeter) `sandbox screendump` still
gives a picture over QMP. Note it misses the hardware cursor plane — anything
about the pointer must go through `grim`.

### 6. Harden, so the work does not evaporate

- Expressible headlessly → move it into `flake.featureTests.<f>.testScript` or
  `featureMeta.<f>.provides`. From then on `nix flake check` guards it.
- Not expressible → a dated entry in the feature's `notes.md`, in the
  `Symptom → Cause → Fix` shape `CONTEXT.md` defines.

The `check.sh` stays either way: it is the live-runtime half of the feature.

### 7. Tear down and report

```bash
nix run .#sandbox -- down    # screenshots survive under /tmp/sandbox/
```

Report in this shape, in the user's language:

> **feature:** `<f>` — ✅ działa / ❌ nie działa
> **czerwone:** which assertions failed on the base (proof they measure something)
> **zielone:** the same assertions after deploy
> **na oczy:** the screenshots, embedded in the reply
> **utwardzone:** what moved into the feature test / `provides`
> **do notatek:** what went to `notes.md` and why it could not be a test
> **niesprawdzone:** what this run did not touch

The last line is not optional. "Wszystko działa" without a scope is the claim the
user cannot check.

## Boundaries the sandbox does not cross

- **NAT only.** QEMU user-net has no LAN. `localsend`/`tailscale` reach "the
  process listens", never "it found the other device".
- **One feature, one VM.** Interactions *between* features are Tier 2, not this.
- **No second account.** `work`-vs-`wiktor` isolation is Tier 2 as well.
- **Not in CI.** `nix flake check` stays the automated gate; this is a tool for
  discovery, and its output is a report plus whatever you managed to harden.
