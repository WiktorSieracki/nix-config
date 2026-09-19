{
  inputs,
  config,
  lib,
  ...
}: let
  inherit (config.flake) agentSkillsLib;

  root = inputs.cursor-plugins + "/pstack";

  # Discovered from disk for the same reason the skills are (see
  # agent-skills-lib.nix): upstream adds and renames agents, and a hardcoded
  # list rots into dangling symlinks with a green build.
  agentFiles =
    lib.filterAttrs
    (name: type: type == "regular" && lib.hasSuffix ".md" name)
    (builtins.readDir (root + "/agents"));
in {
  # pstack — a Cursor plugin (github:cursor/plugins//pstack) shipping ~47 skills
  # driven by `poteto-mode`, plus two subagents. HM-only feature.
  #
  # The skills go to every agent root; the subagents are a Claude Code concept
  # (~/.claude/agents/), with no equivalent in Codex or Gemini CLI, so they are
  # linked there only. `automations/` is Cursor-specific and deliberately skipped.
  flake.modules.homeManager.pstack.home.file =
    agentSkillsLib.links (agentSkillsLib.discover (root + "/skills"))
    // lib.mapAttrs' (name: _: lib.nameValuePair ".claude/agents/${name}" {source = root + "/agents/${name}";}) agentFiles;

  # kind `config`: static files under $HOME; nothing to run.
  #
  # `conflicts`: pstack and mattpocock-skills both ship `tdd` and `teach`, so
  # enabling both is an eval-time home.file clash. The deeper reason to keep them
  # apart is size — two full skill systems at once is more than a person can hold
  # — so the loader hard-fails instead of us silently picking a winner.
  flake.featureMeta.pstack = {
    requires = [];
    conflicts = ["mattpocock-skills"];
    kind = "config";
    # `poteto-mode` is the entry point every other skill hangs off; one agent
    # file covers the second link root.
    provides.userFiles = [
      "~/.claude/skills/poteto-mode/SKILL.md"
      "~/.agents/skills/poteto-mode/SKILL.md"
      "~/.gemini/skills/poteto-mode/SKILL.md"
      "~/.claude/agents/poteto-agent.md"
    ];
  };

  # feature test: the shared sweep over the three skill roots, plus the agents
  # dir — which `agentSkillsLib.testScript` knows nothing about.
  flake.featureTests.pstack.testScript =
    agentSkillsLib.testScript
    + ''
      dangling_agents = machine.succeed(
          "find -L ~tester/.claude/agents -maxdepth 1 -type l -print"
      ).strip()
      assert dangling_agents == "", f"dangling agent symlinks: {dangling_agents}"
    '';
}
