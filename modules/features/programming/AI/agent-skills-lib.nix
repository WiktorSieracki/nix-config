{lib, ...}: {
  # Not a feature — it defines no `flake.modules.*`, so `feature-coverage` never
  # sees it and it needs no featureMeta/feature test of its own. It is the shared
  # half of the skill features (`mattpocock-skills`, `local-skills`), which
  # otherwise would hold a copy each of the same discovery + fan-out logic.
  #
  # Declared as its own option rather than added to `flake.lib`: `flake.lib` is an
  # undeclared freeform output with a single writer already (mkHostUser in
  # hosts/configurations.nix) and flake-parts won't merge a second definition.
  options.flake.agentSkillsLib = lib.mkOption {
    type = lib.types.attrsOf lib.types.anything;
    default = {};
    description = "Helpers shared by the skill features: agent skill roots, disk discovery, link fan-out.";
  };

  config.flake.agentSkillsLib = rec {
    # `SKILL.md` is a cross-agent standard; only the directory each agent reads
    # differs. This list is the single place that knowledge lives — teaching the
    # config about another agent is one line here, not one per skill feature.
    #   ~/.claude/skills  — Claude Code
    #   ~/.agents/skills  — Codex (also scans $CWD and the repo root)
    #   ~/.gemini/skills  — Gemini CLI
    roots = [".claude/skills" ".agents/skills" ".gemini/skills"];

    # A skill is any directory containing a SKILL.md. Discovered from disk rather
    # than listed by hand, so a `nix flake update` that adds, renames or drops an
    # upstream skill is reflected automatically instead of leaving the linked set
    # silently stale (or dangling) — see mattpocock-skills/notes.md, 2026-08-05.
    discover = root:
      lib.mapAttrs (name: _: root + "/${name}")
      (lib.filterAttrs
        (name: type: type == "directory" && builtins.pathExists (root + "/${name}/SKILL.md"))
        (builtins.readDir root));

    # { <name> = <path>; } → home.file entries linking every skill into every
    # agent root. Each link is a symlink to the store copy of the skill folder.
    links = skills:
      lib.listToAttrs (lib.concatMap (
          root:
            lib.mapAttrsToList
            (name: src: lib.nameValuePair "${root}/${name}" {source = src;})
            skills
        )
        roots);

    # The assertions every skill feature's feature test repeats: nothing dangles,
    # and every linked directory really is a skill. Each test VM contains only the
    # feature under test, so sweeping the whole root is exactly right.
    testScript = ''
      for root in ["~tester/.claude/skills", "~tester/.agents/skills", "~tester/.gemini/skills"]:
          dangling = machine.succeed(f"find -L {root} -maxdepth 1 -type l -print").strip()
          assert dangling == "", f"dangling skill symlinks in {root}: {dangling}"
          machine.succeed(
              f"for s in {root}/*/; do test -f \"$s/SKILL.md\" || "
              f"{{ echo \"missing SKILL.md: $s\"; exit 1; }}; done"
          )
    '';
  };
}
