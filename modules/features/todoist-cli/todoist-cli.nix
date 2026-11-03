{config, ...}: let
  inherit (config.flake) agentSkillsLib;
in {
  # Doist's official CLI (`td today`, `td add "…"`) and the agents' `todo`
  # skill that drives it — split out of `todoist` so headless hosts (the VPS)
  # get the list without the desktop app and the bar plugin. The token is
  # per-account state, not SOPS: `td auth login` (OAuth) or `td auth token`
  # stores it — see notes.md for the headless flow.
  flake.modules.nixos.todoist-cli = {pkgs, ...}: {
    environment.systemPackages = [pkgs.todoist-cli];
  };

  flake.modules.homeManager.todoist-cli.home.file = agentSkillsLib.links {todo = ./todo;};

  flake.featureMeta.todoist-cli = {
    requires = [];
    kind = "cli";
    provides = {
      systemBins = ["td"];
      userFiles = [
        "~/.claude/skills/todo/SKILL.md"
        "~/.agents/skills/todo/SKILL.md"
        "~/.gemini/skills/todo/SKILL.md"
      ];
    };
  };

  # feature test: `provides` covers the binary and the skill links. Without a
  # token, td fails with the message the bar plugin keys "needs auth" on.
  flake.featureTests.todoist-cli = {
    testScript =
      agentSkillsLib.testScript
      + ''
        machine.succeed("td --help")
        out = machine.fail("su - tester -c 'td today --json' 2>&1")
        assert "No API token" in out, out
      '';
    extraNixosModules = agentSkillsLib.testModules;
  };
}
