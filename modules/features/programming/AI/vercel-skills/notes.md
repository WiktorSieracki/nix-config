# vercel-skills — feature notes

Links everything under `skills/` in
[vercel-labs/skills](https://github.com/vercel-labs/skills) (flake input
`vercel-skills`) into every agent skill root. Bump with
`nix flake update vercel-skills`.

2026-09-19: Split out of the old `claude-skills` feature so each skill source is
switchable on its own. Upstream ships a single flat `skills/` directory
(currently just `find-skills`), so unlike `mattpocock-skills` there is no
category curation and nothing to `throw` about — discovery from disk covers it.
