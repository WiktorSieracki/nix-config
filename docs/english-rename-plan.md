# English rename — migration plan

Temporary tracking doc. Delete once every phase is done. Goal: everything in the
repo is English. Only LLM conversations stay Polish; the memory files under
`~/.claude/...` are out of scope (outside the repo).

## Term map (decided)

| Old (coined / Polish) | New (descriptive English) | Code artifacts to rename |
| --------------------- | ------------------------- | ------------------------ |
| Próba (Tier-1 per-feature `nixosTest`) | **feature test** | `modules/proba.nix`→`feature-tests.nix`; `flake.probaTests`→`featureTests`; `flake.proba`→`featureTestLib`; `mkProba`→`mkFeatureTest`; `.github/workflows/proba.yaml`→`feature-tests.yaml` |
| Próba hosta (Tier-2 e2e) | **host test** | check names `host-<name>` already English — keep |
| Dziennik (`notes.md`) | **feature notes** | filename `notes.md` already English — prose only |
| Tożsamość (`meta.users`) | **identity** | attr already English — prose only |

Check names `feature-<name>`, `feature-coverage`, `core-smoke` stay as-is.

## Phases

Ordered so the repo stays green at every commit boundary.

### Phase 1 — code rename (one atomic commit; `nix flake check` must pass)

The flake attrs are cross-referenced (harness defines `mkProba`, 51 feature files
register `probaTests.<name>`, the harness turns them into `checks.feature-<name>`),
so this is a single unit — half-renamed does not evaluate.

- [x] `git mv modules/proba.nix modules/feature-tests.nix`
- [x] In it: `probaTests`→`featureTests`, `proba`→`featureTestLib`, `mkProba`→`mkFeatureTest`; translated the Polish comments.
- [x] Renamed `flake.probaTests.<name>`→`flake.featureTests.<name>` across all feature `.nix` files.
- [x] Renamed the neutral test account `proba`→`tester` / `proba2`→`tester2`, `Proba Testowa`→`Test User`, `Proba Druga`→`Second Test User` (harness + ~18 feature testScripts).
- [x] `git mv .github/workflows/proba.yaml .github/workflows/feature-tests.yaml`; `name: Próba`→`Feature tests`, job id `proba`→`feature-tests`, concurrency group, translated comments.
- [x] Verified: full flake eval green, `feature-coverage` green, `feature-git` + `host-users` VM tests green.

### Phase 2 — CONTEXT.md

- [x] Rewrote the glossary in English using the descriptive terms; concepts and
      structure preserved, test account referred to as `tester`.

### Phase 3 — ADRs (`docs/adr/0001..0004`)

- [x] Translated all four to English. Decisions/rationale intact; terms swapped per the map.

### Phase 4 — feature prose

- [x] Translated every `notes.md` (feature notes) to English (43 files).
- [x] Translated Polish comments inside feature `.nix` files (incl. meta.nix prose;
      `Próba`→feature test everywhere).

### Phase 5 — repo-local skills (`.claude/skills/*/SKILL.md`)

- [x] `nix-loop`, `install-feature`, `update-feature`, `remove-feature`: replaced
      "Próba"→"feature test", "Dziennik"→"feature notes", attr names per the map.
      (One `[[project_proba_harness]]` wikilink left — it points at an out-of-scope
      memory file; renaming that file is out of scope.)

### Phase 6 — agent docs

- [x] `CLAUDE.md` Architecture section: "Próba harness"→"feature-test harness",
      "Dziennik"→"feature notes", `proba.nix`→`feature-tests.nix`, etc.
- [x] `AGENTS.md`, `docs/agents/*`, `docs/running-the-vm.md`: swept.
- [x] Also translated the Polish comments + release body in
      `.github/workflows/iso.yaml`, and the `Próba` comment in `switchboard/main.go`.

## Out of scope

- Memory files under `~/.claude/.../memory/` — outside the repo.
