{
  inputs,
  config,
  ...
}: {
  # Mod+C drops straight into a claude session on this repo. Uses the canonical
  # terminal from meta.programs and --working-directory so the session starts in
  # the nix-config checkout regardless of where niri was launched from.
  flake.niriBinds.claude-code = {
    pkgs,
    lib,
  }: {
    "Mod+C" = _: {
      props."hotkey-overlay-title" = "Open nix-config in Claude Code";
      content."spawn-sh" = "${lib.getExe pkgs.${config.flake.meta.programs.terminal}} --working-directory=$HOME/.config/nix-config -e ${lib.getExe inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code}";
    };
  };

  flake.modules.nixos.claude-code = {pkgs, ...}: {
    environment.systemPackages = [
      inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code
    ];
  };

  # The user-global instructions (~/.claude/CLAUDE.md) come from the shared
  # agent-agnostic ../AGENTS.md. Linked out of the store into this account's
  # own checkout, so edits there are live in the next session
  # without a rebuild, and tools that append to it (e.g. `graphify install`)
  # write straight into the repo.
  flake.modules.homeManager.claude-code = {config, ...}: {
    home.file.".claude/CLAUDE.md".source =
      config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/.config/nix-config/modules/features/programming/AI/AGENTS.md";
  };

  flake.featureMeta.claude-code = {
    requires = [];
    kind = "cli";
    # Binary name from meta.mainProgram: claude-code → "claude".
    provides.systemBins = ["claude"];
  };

  # Not in provides.userFiles: its `test -e` follows the link, and the test
  # account has no checkout of the repo, so the link is dangling there.
  flake.featureTests.claude-code.testScript = ''
    machine.succeed("su - tester -c 'readlink -m ~/.claude/CLAUDE.md' | grep -qx /home/tester/.config/nix-config/modules/features/programming/AI/AGENTS.md")
  '';
}
