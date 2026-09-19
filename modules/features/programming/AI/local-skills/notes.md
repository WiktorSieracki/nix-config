# local-skills — feature notes

The skills written (or rescued) in this repo rather than pulled from an upstream
input: `create-issue/` (hand-written, no upstream), `obsidian-vault/` (rescued
from mattpocock, see below) and `todo/` (drives the noctalia todo plugin over
`noctalia-ipc`).

2026-07-18: Created as `claude-skills`. Replaces the manual `~/.claude/skills/*`
symlinks (which pointed into `~/.agents/skills/`, populated by the upstream skill
installer + `.skill-lock.json`) with declarative home-manager links.

`obsidian-vault` was deleted upstream entirely (not moved — mattpocock dropped
the whole `personal` category in Aug 2026), so it is vendored here from the last
revision that shipped it.

## 2026-09-19 — renamed to `local-skills`, sources split out, links made agent-agnostic

The feature linked three sources at once (mattpocock, vercel, vendored) into
`~/.claude/skills` only. Two changes:

- **Split**: `mattpocock-skills` and `vercel-skills` are now their own features,
  so switchboard can switch a third-party set off without taking the
  hand-written skills with it. What stayed here is what this repo owns — hence
  the rename from `claude-skills` (the old name also claimed a Claude tie the
  files never had).
- **Agent-agnostic links**: `SKILL.md` is a cross-agent standard and only the
  directory differs, so every skill is now linked into `~/.claude/skills`
  (Claude Code), `~/.agents/skills` (Codex — it also scans `$CWD` and the repo
  root) and `~/.gemini/skills` (Gemini CLI). The root list and the fan-out live
  in `../agent-skills-lib.nix`; adding an agent is one line there.

**`~/.agents/skills` is a shared root, not ours alone.** It was populated by the
`npx skills` installer (`~/.agents/.skill-lock.json`), whose copies of the
mattpocock/vercel skills collided name-for-name with what nix now links. The
migration removed the 24 colliding directories and pruned their lock entries;
what remains there is installer-owned and untouched by nix (`higgsfield-*`,
`orca-cli`, `orchestration`, `computer-use`). Home-manager refuses to overwrite a
foreign file, so if `npx skills update` ever reinstalls a skill nix owns, HM
activation fails with a clobber error on that path — remove the installer's copy
(and its lock entry), don't disable the feature.

## 2026-09-19 — vercel-labs/skills dropped

The `vercel-skills` feature (and its flake input) shipped exactly one skill,
`find-skills`, whose job is to search and install skills through `npx skills`.
That installer is the thing this config replaced: skills arrive here as pinned
flake inputs, so a skill that recommends a second, unpinned install path is a
route back to the split-brain `~/.agents/skills` the migration above cleaned up.
Removed rather than left switched off — bring it back as its own feature if
upstream ever ships more than the one skill.
