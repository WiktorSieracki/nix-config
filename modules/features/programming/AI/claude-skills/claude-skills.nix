{inputs, ...}: let
  mp = inputs.mattpocock-skills;

  # Skill name → its category folder inside the mattpocock/skills repo. Mirrors
  # the layout the upstream installer resolves via SKILL.md paths; kept explicit
  # here so a `nix flake update` that moves a skill fails loudly at build.
  mattpocockSkills = {
    engineering = [
      "ask-matt"
      "code-review"
      "codebase-design"
      "diagnosing-bugs"
      "domain-modeling"
      "grill-with-docs"
      "implement"
      "improve-codebase-architecture"
      "prototype"
      "research"
      "resolving-merge-conflicts"
      "setup-matt-pocock-skills"
      "tdd"
      "to-spec"
      "to-tickets"
      "triage"
      "wayfinder"
    ];
    productivity = [
      "grill-me"
      "grilling"
      "handoff"
      "teach"
      "writing-great-skills"
    ];
    personal = [
      "obsidian-vault"
    ];
  };
in {
  # Links Claude Code skills into ~/.claude/skills/<name>, each a symlink to the
  # store copy of the skill folder. HM-only feature. Sources: mattpocock/skills
  # and vercel-labs/skills (pinned flake inputs, flake = false) plus one locally
  # vendored skill (create-issue). Mirrors the manual `~/.claude/skills/*`
  # symlink layout the upstream installer produces, but declaratively.
  flake.modules.homeManager.claude-skills = {lib, ...}: {
    home.file =
      lib.foldl' (
        acc: category:
          acc
          // lib.listToAttrs (map (name: {
              name = ".claude/skills/${name}";
              value.source = mp + "/skills/${category}/${name}";
            })
            mattpocockSkills.${category})
      ) {} (builtins.attrNames mattpocockSkills)
      // {
        ".claude/skills/find-skills".source = inputs.vercel-skills + "/skills/find-skills";
        ".claude/skills/create-issue".source = ./create-issue;
      };
  };

  # kind `config`: static skill files under $HOME; nothing to run. Requires
  # claude-code — the skills are only meaningful to the Claude Code CLI.
  flake.featureMeta.claude-skills = {
    requires = ["claude-code"];
    kind = "config";
  };

  # feature test: the linked skill files land in the test user's home. Spot-check
  # one skill from each source (mattpocock, vercel, vendored).
  flake.featureTests.claude-skills = {
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("home-manager-tester.service")
      machine.succeed("test -f ~tester/.claude/skills/tdd/SKILL.md")
      machine.succeed("test -f ~tester/.claude/skills/find-skills/SKILL.md")
      machine.succeed("test -f ~tester/.claude/skills/create-issue/SKILL.md")
    '';
  };
}
