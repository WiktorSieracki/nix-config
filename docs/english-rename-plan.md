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

- [ ] `git mv modules/proba.nix modules/feature-tests.nix`
- [ ] In it: `probaTests`→`featureTests`, `proba`→`featureTestLib`, `mkProba`→`mkFeatureTest`; translate the Polish comments.
- [ ] Rename `flake.probaTests.<name>`→`flake.featureTests.<name>` across all 51 feature `.nix` files.
- [ ] `git mv .github/workflows/proba.yaml .github/workflows/feature-tests.yaml`; `name: Próba`→`Feature tests`, job id `proba`→`feature-tests`, concurrency group, translate comments.
- [ ] `nix flake check` (or at least eval + `feature-coverage`) green.

### Phase 2 — CONTEXT.md

- [ ] Rewrite the glossary in English using the descriptive terms. Keep the same
      concepts and structure; drop the `_Avoid_` entries that only existed to steer
      away from Polish synonyms, keep those that still carry meaning.

### Phase 3 — ADRs (`docs/adr/0001..0004`)

- [ ] Translate all four to English. Keep decisions/rationale intact; swap terms per the map.

### Phase 4 — feature prose

- [ ] Translate every `notes.md` (feature notes) to English.
- [ ] Translate Polish comments inside feature `.nix` files.

### Phase 5 — repo-local skills (`.claude/skills/*/SKILL.md`)

- [ ] `nix-loop`, `install-feature`, `update-feature`, `remove-feature`: replace
      "Próba"→"feature test", "Dziennik"→"feature notes", attr names per the map.

### Phase 6 — agent docs

- [ ] `CLAUDE.md` Architecture section: "Próba harness"→"feature-test harness",
      "Dziennik"→"feature notes", `proba.nix`→`feature-tests.nix`, etc.
- [ ] `AGENTS.md`, `docs/agents/*`, `docs/running-the-vm.md`: sweep for stragglers.

## Out of scope

- Memory files under `~/.claude/.../memory/` — outside the repo.
