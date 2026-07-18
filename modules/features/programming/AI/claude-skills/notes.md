# claude-skills — feature notes

2026-07-18: Created. Replaces the manual `~/.claude/skills/*` symlinks (which
pointed into `~/.agents/skills/`, populated by the upstream skill installer +
`.skill-lock.json`) with declarative home-manager links.

Sources:
- `mattpocock/skills` (flake input `mattpocock-skills`, `flake = false`) — 23
  skills across `engineering/`, `productivity/`, `personal/`.
- `vercel-labs/skills` (flake input `vercel-skills`) — `find-skills` only.
- `create-issue` — vendored in this folder (`./create-issue/`), a hand-written
  local skill with no upstream repo.

Bump the third-party skills with `nix flake update mattpocock-skills` /
`nix flake update vercel-skills`. If an upstream reorg moves a skill between
category folders, the `mattpocockSkills` map here goes stale and the build fails
on a missing store path — update the category list.
