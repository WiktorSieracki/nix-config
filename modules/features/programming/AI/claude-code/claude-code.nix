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

  flake.featureMeta.claude-code = {
    requires = [];
    kind = "cli";
    # Binary name from meta.mainProgram: claude-code → "claude".
    provides.systemBins = ["claude"];
  };

  # feature test: fully covered by `provides` — no extra script needed.
  flake.featureTests.claude-code = {};
}
