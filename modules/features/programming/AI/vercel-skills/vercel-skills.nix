{
  inputs,
  config,
  ...
}: let
  inherit (config.flake) agentSkillsLib;
in {
  # Links everything under vercel-labs/skills (currently just `find-skills`) into
  # every agent's skill root. HM-only feature. No category curation here — the
  # repo ships a single flat `skills/` directory. Bump with
  # `nix flake update vercel-skills`.
  flake.modules.homeManager.vercel-skills.home.file =
    agentSkillsLib.links (agentSkillsLib.discover (inputs.vercel-skills + "/skills"));

  # kind `config`: static skill files under $HOME; nothing to run. No `requires`
  # — SKILL.md is a cross-agent standard, so these links are useful to whichever
  # agent CLI is installed (or to none yet), not to Claude Code specifically.
  flake.featureMeta.vercel-skills = {
    requires = [];
    kind = "config";
    # One skill per agent root; the feature test sweeps the rest.
    provides.userFiles = [
      "~/.claude/skills/find-skills/SKILL.md"
      "~/.agents/skills/find-skills/SKILL.md"
      "~/.gemini/skills/find-skills/SKILL.md"
    ];
  };

  # feature test: `provides` spot-checks one skill per root; this asserts the
  # whole tree resolves in all three.
  flake.featureTests.vercel-skills.testScript = agentSkillsLib.testScript;
}
