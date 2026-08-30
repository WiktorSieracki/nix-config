# nix-config

Glossary of this NixOS configuration's terms. Not a spec or a log of
implementation decisions — just a way to keep the language consistent.

## Language

**Host**:
A named machine configuration in `flake.nixosConfigurations.*`, assembled from
**system features** (the `system` section) and **user features** enabled per
account (the `users.<login>` section). Real machines (`desktopNixos`,
`laptopNixos`) depend on their `hardware-configuration.nix` and SOPS secrets.
_Avoid_: machine, target, profile.

**System feature**:
A **feature** that is a property of the machine (hardware, network, services —
`nvidia`, `ssh-server`, `tailscale`). A **Host** enables it once, in the
`system` section; it belongs to no account.
_Avoid_: global feature.

**User feature**:
A **feature** that is part of a specific account's environment (`git`, `fish`,
`vscode`, apps). A **Host** enables it per user in `users.<login>`; the same
feature may have several users, but its content knows only one *abstract* user —
identity is injected from the outside.
_Avoid_: user module, profile feature.

**Feature**:
A reusable module in `modules/features/*`, usually defining a NixOS part and a
home-manager part under the same name. A **Host** enables **features** by name.
A feature is *self-sufficient*: it declares its dependencies explicitly and has
no **functional** coupling to neighbouring files (helper .sh/.json live in its
store path, not imported from outside the module). The layout is
**folder-per-feature** (`git/{git.nix, notes.md}`); documentation alongside it
(**feature notes**) is allowed — it is not a functional dependency, since the
feature works without it.
_Avoid_: module (too general — a `feature` is specifically this pattern),
package (confusing with an nixpkgs package — here the unit is a `feature`).

**Identity** (`meta.users`):
The canonical registry of accounts in `flake.meta.users.<login>`: full name,
groups, shell, addresses. An account exists on a **Host** ⇔ its login is a key
of that host's `users` section — the loader creates it, not a feature. A **user
feature** receives its identity injected and never hardcodes a login.
_Avoid_: user feature (the old `wiktor` feature), account config.

**Kind** (of a feature):
A machine-readable category in `featureMeta.<feature>.kind` that says *what* a
feature is and how "it works" is checked: `config` (pure configuration —
validated by eval + a validator such as `niri validate`), `cli` (a binary on
PATH, `--version`/smoke → exit 0), `service` (a systemd unit `active` + port
listen), `gui` (the process starts and holds a window in the session). It sets
the rigor level of the **feature test** — concretely, it decides which
**Provides** a feature is obliged to declare, and `feature-coverage` hard-fails
when the obligation is unmet.
_Avoid_: type, category.

**Provides** (`featureMeta.<feature>.provides`):
What a feature puts on the system, declared rather than asserted by hand:
`systemBins`, `userBins`, `units`, `ports`, `files`, `userFiles`. `mkFeatureTest`
turns each entry into the corresponding assertion, so the boot/activation/PATH
lines every **feature test** used to hand-copy live in one place. A feature test's
`testScript` is what's left over — behaviour a declaration can't express — and is
optional. The pairing with **Kind** is what stops a feature test from existing
while asserting nothing: a `cli`/`gui` feature must name a binary, a `service`
must name a unit, unless it is **runtimeUntestable**.
_Avoid_: outputs, artifacts, expectations.

**Requires**:
A feature's explicit dependency list in `featureMeta.<feature>.requires`. The
loader **hard-fails** when a host enables a feature without the full set of its
`requires` also listed — the dependency graph is always the whole truth (for
human and AI). The **feature test** computes the minimal VM closure from it.
_Avoid_: deps, imports (the latter means something else in Nix).

**Core** (floor):
The irreducible minimum of the system, present in *every* feature test and every
"ambient" host (boot, nix, network, locale, nix-ld) — what remains after the
desktop layer is lifted out of today's `nixos` bag. A feature does **not** list
`core` in **Requires** (it is always underneath). The minimal feature-test VM =
`core` + feature + the `requires` closure.
_Avoid_: base (the `nixos` bag was the "base", but a fat one fused with niri —
`core` is the deliberately slimmed layer).

**Desktop** (feature):
The graphical-session layer split out of the old base (`xserver`, `gdm`,
`defaultSession=niri`, GUI packages). A feature of **Kind** `gui` explicitly
`requires = ["desktop" ...]`. This way a `cli` feature starts on `core` alone and
its feature test detects a hidden dependency on the desktop.
_Avoid_: gui-base, session.

**Feature test** (Tier 1):
A headless `nixosTest` that builds the **minimal** VM = the feature under test +
the closure of its **Requires**, and asserts the feature "works" at the rigor
level of its **Kind**. Most of it is generated from **Provides**; the registered
spec (`flake.featureTests.<name>`) carries only the remainder — an extra
`testScript`, `extraNixosModules`, `extraHmModules` — and may legitimately be
empty (`{}`). Mandatory for *every* feature (CI fails without it) — even
a trivial feature with a single `systemPackage` must prove its binary runs. It
fails when a feature has an undeclared dependency → it forces modularity
structurally. **User features** are tested on a neutral test account (`tester`),
not on a real login — hardcoding someone's login in a feature breaks its feature
test.
_Avoid_: smoke test, unit test.

**Host test** (Tier 2, e2e):
A headless test that boots a whole **Host** (or a curated group of features) and
checks assertions *between* features (e.g. "the user is in the docker group AND
`docker run` passes"). This is the "end-to-end" — integration, not isolation.
Rarer, a thinner layer over the feature tests.
_Avoid_: integration test.

**Feature notes** (`notes.md`):
A dated record of a feature's **non-executable** knowledge: upstream quirks, "why
this workaround", environment gotchas. Read by `/nix-loop` at start (so known
problems aren't re-derived from scratch) and auto-appended with a date when the
loop resolves something new. The boundary with the **feature test**: a
*reproducible* bug goes into the feature test as an assertion (it won't rot);
feature notes hold only what can't sensibly be encoded in a test. Entry
structure: `Symptom → Cause → Fix`.
_Avoid_: README, docs.

**runtimeUntestable** (flag in `featureMeta`):
Escape hatch (c) from ADR 0002: marks a feature whose *runtime* can't be verified
in a VM (no hardware — `nvidia`/`wacom`/`mouse`; no real network/SOPS key —
`eduroam`/`home-wifi`/`sops`). Such a feature **still has a feature test**, but it
only checks that the module integrates and the system boots (eval/boot
regression), not the hardware/secret itself.
_Avoid_: untestable, skip.

**Work user**:
A second ordinary Unix account (`work`) on the same **Host** as the main user —
separation of *data and identity* (profiles, accounts, secrets, history), not of
executability (no MAC). No sudo, homeMode 700. A **managed** account: its **user
features** are switched and activated by the main user — the right to rebuild the
system would equal root and void the isolation.
_Avoid_: separate host, work VM, work account as a machine.

**Switchboard**:
A TUI (feature `switchboard`, binary `switchboard`) for managing the feature
lists of real **hosts** — separately for the `system` section and each
`users.<login>` (including the **work user**, in the main user's hands):
checkboxes with search, explicit **Requires** closure on selection, a feature
diff as confirmation, finishing through `nh os test`/`switch`; globally it also
bumps `flake.lock`. It edits host data files — it never touches `.nix`.
_Avoid_: features-cli, manager, panel.

**ISO** (minimal installer):
A single **generic** installer image (host `iso`), bootable on any machine. It
is not a "laptop image", a "desktop image", or a live desktop — it is the
smallest thing that can partition a disk, get networking up (`nmtui`) and run
`nixos-install`. Contents: the stock minimal installer + the **core** floor +
the `nix` and `fish` **features** + plain `pkgs.git`. It carries no graphical
session, no **host**-specific hardware features (`nvidia/wacom/mouse`) and no
secret-dependent ones (`sops/git/eduroam/...`) — the latter can't activate
without the machine's key anyway. The target **host** is chosen only at install
time (`nixos-install --flake github:...#desktopNixos | #laptopNixos`), and
everything that host runs is fetched then, out of the **host closure cache**.
_Avoid_: live image, live ISO, per-machine image, per-host installer.

**Host closure cache**:
The `wiktor-nixos` Cachix cache, filled on every push to `main` by
`.github/workflows/hosts.yaml`, which builds `system.build.toplevel` for
`desktopNixos` and `laptopNixos` (exposed as
`packages.x86_64-linux.<host>-system`). It is what makes the thin **ISO**
workable: a fresh install substitutes this repo's own packages instead of
building them. Also the only check that both real hosts still build.
_Avoid_: binary cache (ambiguous — `cache.nixos.org` is one too), CI artifact.

**Release** (rolling `latest`):
A single, overwritten GitHub release under the tag `latest`, carrying the latest
**ISO** + `checksums.txt` as one file each. Cut **manually**
(`workflow_dispatch`), not on every push — the installer image barely changes,
while the **host closure cache** is what has to track `main`. A stable download
URL instead of dated history.
_Avoid_: snapshot, versioned release.

### Flagged ambiguities

- **"image"** is sometimes confused with "an image of a specific machine". In
  this repo we ship **one generic ISO**; per-machine images were rejected because
  after filtering out hardware and secrets, `iso-desktop` and `iso-laptop` would
  be nearly identical — and once the ISO became a minimal installer the question
  stopped being meaningful at all.
- **"the ISO has my setup on it"** — it does not, and deliberately so. The
  **ISO** installs a **host**; the setup comes down from the **host closure
  cache** during `nixos-install`.

### Example dialogue

> — Let's cut a new **release**.
> — OK — that's a manual run of the ISO workflow; it builds the **ISO** from the
>   `iso` host and overwrites the `latest` tag. A push to `main` doesn't do it,
>   a push only refreshes the **host closure cache**.
> — And how do I install a laptop from it?
> — You boot the same **ISO** and run `nixos-install --flake .#laptopNixos` — the
>   **host** choice happens at install time, not at download time, and the
>   closure comes out of the cache rather than being built on the spot.
>
> — I want slack on the work account.
> — `slack` is a **user feature** — with Switchboard you add it to `users.work`
>   on the desktop and activate it as wiktor; the **work user** is a managed
>   account.
> — And how does the work git know which email to commit with?
> — From the **Identity**: `meta.users.work` points at the secret with the work
>   email, and the `git` feature receives it injected — it knows no login itself,
>   which its **feature test** on the `tester` account enforces.
