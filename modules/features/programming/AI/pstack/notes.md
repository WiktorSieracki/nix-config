# pstack — feature notes

[pstack](https://github.com/cursor/plugins/tree/main/pstack) is a Cursor plugin
by poteto: ~47 skills, two subagents, and a set of playbooks. Consumed from the
`cursor-plugins` input (Cursor's plugin monorepo, `flake = false`); only
`pstack/` is linked. Bump with `nix flake update cursor-plugins`.

2026-09-19: Added, replacing `mattpocock-skills` on both hosts.

**It is one system, not a menu.** `poteto-mode` is the entry point; it picks one
of 23 playbooks and pulls in the other skills as the steps need them. 23 of the
47 skills are `principle-*`, and they — like `tdd`, `teach` and most of the rest
— carry `disable-model-invocation: true`, so they never enter the auto-trigger
pool and cost no context until something invokes them by name. Installing a
subset would break the references, so the feature takes `skills/` whole.

**Mutually exclusive with `mattpocock-skills`** (`featureMeta.conflicts`, added
to the harness for this). Two reasons, in order:

1. Both ship a `tdd` and a `teach`. Two features defining the same
   `home.file` is an eval error naming a *path*, which tells you nothing about
   which features fought — hence the loader-level check, which names both.
2. The real reason to keep them apart: each is a complete engineering system
   with its own vocabulary, and running both at once is more skills than a
   person can keep in their head.

Switching back is one toggle in switchboard — the mattpocock feature stays in the
repo, just disabled on both hosts.

`automations/benny` is Cursor-specific (the `automations/` directory is a Cursor
plugin concept with no counterpart in Claude Code, Codex or Gemini CLI) and is
not linked. The two subagents under `agents/` are linked to `~/.claude/agents/`
only, for the same reason: Codex and Gemini CLI have no subagent directory.

Not wired up here: `/setup-pstack` is a per-repo, prompt-driven step (it asks for
a reasoning budget and a model panel, and writes into the repo). Run it by hand
in a repo once; nothing about it belongs in the system config.
