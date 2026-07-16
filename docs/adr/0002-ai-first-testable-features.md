# Feature as a self-sufficient, headless-verifiable unit (AI-first)

Every **Feature** becomes a *self-sufficient and self-describing* unit: in a
single `.nix` file it contributes a NixOS/HM module, **`featureMeta`** (`requires`
+ `kind`), and a mandatory **feature test** — a headless `nixosTest` that builds a
minimal VM (`core` + feature + the `requires` closure) and asserts the feature
"works" at the rigor level of its `kind`. The loader **hard-fails** when a host
enables a feature without the full set of its `requires` listed, and the
eval-time `feature-coverage` fails when a module exists without `featureMeta` or
without a feature test. Goal: modularity *enforced structurally* and a feedback
loop drivable by AI.

## Component decisions

- **`featureMeta.<f> = { requires; kind; }`** — an explicit, machine-readable
  dependency graph. `kind ∈ {config, cli, service, gui}` sets the feature test's
  rigor level (config/cli/service → L2, gui → L1 to start). The `runtimeUntestable`
  flag exempts from runtime assertions features that can't be exercised without
  real infrastructure (e.g. `eduroam`).
- **Feature test on `nixosTest`, not on the interactive `build.vm` runner** —
  headless, deterministic, returns an exit code; fits the AI loop. The `build.vm`
  runner stays for eyeballing by a human.
- **Two levels** — the **feature test** (Tier 1, isolation: min VM = `core` +
  feature + `requires`) and the **host test** (Tier 2, e2e: assertions *between*
  features on a host).
- **Folder-per-feature**: `<f>/{<f>.nix, notes.md}`. The `.nix` file =
  module + meta + feature test, assembled with the helper
  `flake.featureTestLib.mkFeatureTest` (a separate attr, because `flake.lib` is
  undeclared and flake-parts won't merge it across modules). Checks are named
  `feature-<name>` / `host-<name>`. The "self-sufficiency" rule forbids
  *functional* coupling between files, not documentation alongside.
- **Feature notes (`notes.md`)** — a dated record of *non-executable* knowledge
  (upstream quirks, workarounds). `/nix-loop` reads it at start and auto-appends
  with a date after solving a problem. The boundary: a *reproducible* bug →
  an assertion in the feature test (it won't rot); feature notes → only what can't
  be encoded.
- **Splitting the base into `core` + a `desktop` feature** — the old
  `flake.modules.nixos.nixos` bag hardcoded the niri session (`xserver`, `gdm`,
  `defaultSession=niri`, GUI packages), which made the litmus test *"does the
  feature work without niri?"* unfeasible. `core` = the irreducible minimum
  (ambient, not in `requires`); `desktop` = explicitly required by `gui` features.
- **SOPS in the feature test** — by default a **stub** of the secret (path →
  plaintext fixture), with `runtimeUntestable` as the escape hatch for cases that
  can't be exercised.
- **Local-first CI** — eval-time `feature-coverage` + cheap feature tests
  (`cli`/`config`) in CI (a gate against regressions, KVM-independent/light),
  heavy feature tests (`gui`/`service`) locally (KVM on the desktop); green builds
  to the Cachix cache `wiktor-nixos`.

## Considered Options (rejected)

- **Implicit dependencies / Nix-native assertions** — AI can't compute the VM
  closure *up front* (it only learns through an eval error). `featureMeta` is the
  single source of truth for validation, VM assembly, and all the skills.
- **A fat base as the feature-test floor** — simplest, but the litmus test stays
  a fiction (every VM comes up with a full desktop). Rejected in favour of
  `core`+`desktop`.
- **A full `nix flake check` (all feature tests) in CI on every PR** — assumes
  reliable KVM on the runner; risk of slow/brittle CI. Deferred.

## Consequences

- A one-off refactor: splitting the base, adding `featureMeta`+a feature test to
  *each* of ~40 features (recommended rollout: harness + a pilot on one feature,
  then migrate the rest), validation in `loadNixosAndHmModuleForUser`.
- The skills operate on this model: `/search-nix`, `/install-feature`,
  `/update-feature`, `/nix-loop`, `/remove-feature`. `/nix-loop` spins purely in a
  VM (≤5 iterations, stop on a repeated error, autonomous edits to the feature
  file); `nh os test/switch` on metal is always outside the loop and explicit.
- "Package" retired from the project's language in favour of **Feature** — see
  [CONTEXT.md](../../CONTEXT.md).
