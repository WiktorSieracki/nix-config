{config, ...}: let
  inherit (config.flake) agentSkillsLib;
in {
  # The skills written (or rescued) here rather than pulled from an upstream
  # input, linked into every agent's skill root. HM-only feature. Third-party
  # skill sets live in their own features (`mattpocock-skills`) so each source
  # can be switched on and off on its own.
  #
  # A name defined here and upstream at the same time is an eval-time conflict
  # (two features defining the same home.file) — loud, which is what we want:
  # `obsidian-vault` is vendored precisely because mattpocock deleted it, and its
  # return upstream is a decision to make, not a silent shadow.
  flake.modules.homeManager.local-skills.home.file = agentSkillsLib.links {
    "create-issue" = ./create-issue;
    "obsidian-vault" = ./obsidian-vault;
    "todo" = ./todo;
  };

  # kind `config`: static skill files under $HOME; nothing to run. No `requires`
  # — `todo` only shells out to `noctalia-ipc`, and the rest are plain prompts,
  # so these links are useful to whichever agent CLI is installed.
  flake.featureMeta.local-skills = {
    requires = [];
    kind = "config";
    # Every vendored skill in one root, plus the same skill in the other two —
    # this set is small enough to assert exhaustively.
    provides.userFiles = [
      "~/.claude/skills/create-issue/SKILL.md"
      "~/.claude/skills/obsidian-vault/SKILL.md"
      "~/.claude/skills/todo/SKILL.md"
      "~/.agents/skills/todo/SKILL.md"
      "~/.gemini/skills/todo/SKILL.md"
    ];
  };

  # feature test: `provides` spot-checks the links; this asserts the whole tree
  # resolves in all three roots.
  flake.featureTests.local-skills.testScript = agentSkillsLib.testScript;
}
