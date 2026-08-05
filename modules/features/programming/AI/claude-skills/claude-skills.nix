{
  inputs,
  lib,
  ...
}: let
  # A skill is any directory containing a SKILL.md. Discovered from disk rather
  # than listed by hand, so a `nix flake update` that adds, renames or drops an
  # upstream skill is reflected automatically instead of leaving the linked set
  # silently stale (or dangling).
  skillDirs = root:
    lib.filterAttrs
    (name: type: type == "directory" && builtins.pathExists (root + "/${name}/SKILL.md"))
    (builtins.readDir root);

  linksFrom = root:
    lib.mapAttrs'
    (name: _: lib.nameValuePair ".claude/skills/${name}" {source = root + "/${name}";})
    (skillDirs root);

  # Curation happens at *category* granularity: mattpocock/skills also ships
  # `deprecated`, `in-progress` and `misc`, which we deliberately don't install.
  # A category vanishing upstream is a real decision to make, so fail the build
  # loudly instead of quietly installing nothing (this is how `personal` was
  # lost in Aug 2026 — see notes.md).
  mattpocockCategories = ["engineering" "productivity"];

  mattpocockLinks =
    lib.foldl' (
      acc: category: let
        root = inputs.mattpocock-skills + "/skills/${category}";
      in
        if !builtins.pathExists root
        then
          throw ''
            claude-skills: mattpocock/skills no longer has category '${category}'.
            Update `mattpocockCategories` in claude-skills.nix (and vendor any
            skill you want to keep, as was done for obsidian-vault).
          ''
        else acc // linksFrom root
    ) {}
    mattpocockCategories;
in {
  # Links Claude Code skills into ~/.claude/skills/<name>, each a symlink to the
  # store copy of the skill folder. HM-only feature. Sources: mattpocock/skills
  # and vercel-labs/skills (pinned flake inputs, flake = false) plus locally
  # vendored skills. Mirrors the manual `~/.claude/skills/*` symlink layout the
  # upstream installer produces, but declaratively.
  flake.modules.homeManager.claude-skills = {
    home.file =
      mattpocockLinks
      // linksFrom (inputs.vercel-skills + "/skills")
      # Vendored last so a local copy always wins over an upstream skill of the
      # same name. obsidian-vault was deleted upstream (mattpocock dropped the
      # whole `personal` category) but is still in use here.
      // {
        ".claude/skills/create-issue".source = ./create-issue;
        ".claude/skills/obsidian-vault".source = ./obsidian-vault;
      };
  };

  # kind `config`: static skill files under $HOME; nothing to run. Requires
  # claude-code — the skills are only meaningful to the Claude Code CLI.
  flake.featureMeta.claude-skills = {
    requires = ["claude-code"];
    kind = "config";
    # One skill per source (mattpocock, vercel, vendored) — a renamed or removed
    # upstream skill otherwise shows up only as a dangling symlink at runtime,
    # which is exactly how this feature rotted before discovery was automatic.
    provides.userFiles = [
      "~/.claude/skills/tdd/SKILL.md"
      "~/.claude/skills/find-skills/SKILL.md"
      "~/.claude/skills/create-issue/SKILL.md"
      "~/.claude/skills/obsidian-vault/SKILL.md"
    ];
  };

  # feature test: `provides` spot-checks one skill per source; this asserts the
  # whole tree resolves.
  flake.featureTests.claude-skills = {
    testScript = ''
      # No dangling links, and every linked skill really is a skill.
      dangling = machine.succeed(
          "find -L ~tester/.claude/skills -maxdepth 1 -type l -print"
      ).strip()
      assert dangling == "", f"dangling skill symlinks: {dangling}"
      machine.succeed(
          "for s in ~tester/.claude/skills/*/; do test -f \"$s/SKILL.md\" || "
          "{ echo \"missing SKILL.md: $s\"; exit 1; }; done"
      )
    '';
  };
}
