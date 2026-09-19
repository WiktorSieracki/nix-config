# mattpocock-skills — feature notes

Links the `engineering/` and `productivity/` categories of
[mattpocock/skills](https://github.com/mattpocock/skills) (flake input
`mattpocock-skills`, `flake = false`) into every agent skill root. Bump with
`nix flake update mattpocock-skills`.

2026-09-19: Split out of the old `claude-skills` feature, which linked three
sources (mattpocock, vercel-labs, vendored) at once and so could only be
switched on or off as a block. (The vercel-labs set was dropped the same day —
see local-skills/notes.md.) One feature per source means switchboard can drop
this set without losing the hand-written ones. The entries below predate the
split and were moved here from that feature's notes.

2026-08-05: The original implementation hardcoded a skill name → category map,
with a comment claiming a moved skill would "fail loudly at build". It does not:
`input + "/skills/${cat}/${name}"` is path concatenation, and home-manager
happily links a store path that doesn't exist, producing a **dangling symlink**
in `~/.claude/skills/` with a green build and a green feature test. A flake
update that day dropped `personal/` and renamed `writing-great-skills` →
`writing-for-agents` upstream; both broke silently and four new upstream skills
were never picked up.

Fixed by discovering skills from disk (any directory containing `SKILL.md`), so
adds/renames/removals follow upstream automatically — the discovery helper now
lives in `../agent-skills-lib.nix`. Curation is only at *category* granularity —
upstream also ships `deprecated/`, `in-progress/` and `misc/`, which we
deliberately skip — and a listed category disappearing is an explicit `throw`.
The feature test asserts there are no dangling links and that every linked
directory really contains a `SKILL.md`.

`obsidian-vault` was deleted upstream entirely (not moved), so it is vendored in
the `local-skills` feature from the last mattpocock revision that shipped it.

## 2026-09-19 — disabled on both hosts in favour of pstack

Both hosts switched to the `pstack` feature. The two are declared mutually
exclusive (`featureMeta.conflicts` on `pstack`): they both ship a `tdd` and a
`teach`, and more importantly each is a whole engineering system — running both
at once is more vocabulary than a person can hold. This feature stays in the
repo, disabled; switching back is one toggle in switchboard.
