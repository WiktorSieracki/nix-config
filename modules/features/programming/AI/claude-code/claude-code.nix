{
  inputs,
  config,
  ...
}: {
  # Mod+C drops straight into a claude session on this repo. Uses the canonical
  # terminal from meta.programs and --working-directory so the session starts in
  # the nix-config checkout regardless of where niri was launched from.
  flake.niriBinds.claude-code = {pkgs, lib}: {
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

  # The user-global instructions (~/.claude/CLAUDE.md). Kept under another name
  # so Claude Code doesn't pick it up as a nested project CLAUDE.md while
  # working in this repo. Read-only once linked — tools that append to it
  # (e.g. `graphify install`) have to be edited into this file instead.
  flake.modules.homeManager.claude-code.home.file.".claude/CLAUDE.md".source = ./global-claude.md;

  flake.featureMeta.claude-code = {
    requires = [];
    kind = "cli";
    # Binary name from meta.mainProgram: claude-code → "claude".
    provides.systemBins = ["claude"];
    provides.userFiles = ["~/.claude/CLAUDE.md"];
  };

  # feature test: fully covered by `provides` — no extra script needed.
  flake.featureTests.claude-code = {};
}
