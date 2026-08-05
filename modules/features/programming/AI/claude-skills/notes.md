# claude-skills — feature notes

2026-07-18: Created. Replaces the manual `~/.claude/skills/*` symlinks (which
pointed into `~/.agents/skills/`, populated by the upstream skill installer +
`.skill-lock.json`) with declarative home-manager links.

Sources:
- `mattpocock/skills` (flake input `mattpocock-skills`, `flake = false`) — the
  `engineering/` and `productivity/` categories, discovered from disk.
- `vercel-labs/skills` (flake input `vercel-skills`) — everything under
  `skills/` (currently just `find-skills`).
- Vendored in this folder: `create-issue/` (hand-written, no upstream) and
  `obsidian-vault/` (rescued from upstream, see below).

Bump the third-party skills with `nix flake update mattpocock-skills` /
`nix flake update vercel-skills`.

2026-08-05: The original implementation hardcoded a skill name → category map,
with a comment claiming a moved skill would "fail loudly at build". It does not:
`input + "/skills/${cat}/${name}"` is path concatenation, and home-manager
happily links a store path that doesn't exist, producing a **dangling symlink**
in `~/.claude/skills/` with a green build and a green feature test. A flake
update that day dropped `personal/` and renamed `writing-great-skills` →
`writing-for-agents` upstream; both broke silently and four new upstream skills
were never picked up.

Fixed by discovering skills from disk (any directory containing `SKILL.md`), so
adds/renames/removals follow upstream automatically. Curation is now only at
*category* granularity — upstream also ships `deprecated/`, `in-progress/` and
`misc/`, which we deliberately skip — and a listed category disappearing is an
explicit `throw`. The feature test now also asserts there are no dangling links
and that every linked directory really contains a `SKILL.md`.

`obsidian-vault` was deleted upstream entirely (not moved), so it is vendored
here from the last mattpocock revision that shipped it.
