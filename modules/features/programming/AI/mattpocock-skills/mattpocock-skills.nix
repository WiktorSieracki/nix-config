{
  inputs,
  config,
  lib,
  ...
}: let
  inherit (config.flake) agentSkillsLib;

  # Curation happens at *category* granularity: mattpocock/skills also ships
  # `deprecated`, `in-progress` and `misc`, which we deliberately don't install.
  # A category vanishing upstream is a real decision to make, so fail the build
  # loudly instead of quietly installing nothing (this is how `personal` was
  # lost in Aug 2026 — see notes.md).
  categories = ["engineering" "productivity"];

  skills =
    lib.foldl' (
      acc: category: let
        root = inputs.mattpocock-skills + "/skills/${category}";
      in
        if !builtins.pathExists root
        then
          throw ''
            mattpocock-skills: mattpocock/skills no longer has category '${category}'.
            Update `categories` in mattpocock-skills.nix (and vendor any skill you
            want to keep into the `local-skills` feature, as was done for
            obsidian-vault).
          ''
        else acc // agentSkillsLib.discover root
    ) {}
    categories;
in {
  # Links the `engineering` and `productivity` skills from the pinned
  # mattpocock/skills input into every agent's skill root. HM-only feature.
  # Bump with `nix flake update mattpocock-skills`.
  flake.modules.homeManager.mattpocock-skills.home.file = agentSkillsLib.links skills;

  # kind `config`: static skill files under $HOME; nothing to run. No `requires`
  # — SKILL.md is a cross-agent standard, so these links are useful to whichever
  # agent CLI is installed (or to none yet), not to Claude Code specifically.
  flake.featureMeta.mattpocock-skills = {
    requires = [];
    kind = "config";
    # One skill per agent root — a renamed or removed upstream skill otherwise
    # shows up only as a dangling symlink at runtime, which is exactly how this
    # rotted before discovery was automatic (notes.md, 2026-08-05).
    provides.userFiles = [
      "~/.claude/skills/tdd/SKILL.md"
      "~/.agents/skills/tdd/SKILL.md"
      "~/.gemini/skills/tdd/SKILL.md"
    ];
  };

  # feature test: `provides` spot-checks one skill per root; this asserts the
  # whole tree resolves in all three.
  flake.featureTests.mattpocock-skills.testScript = agentSkillsLib.testScript;
}
