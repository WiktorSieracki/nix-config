{
  flake.modules.nixos."custom-scripts" = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      (writeShellScriptBin "gitHttpsToSsh" (
        builtins.readFile ./gitHttpsToSsh.sh
      ))
      (writeShellScriptBin "pull" (builtins.readFile ./pull.sh))
      (writeShellScriptBin "resetnet" (builtins.readFile ./resetnet.sh))
    ];
  };

  # Convenience shell scripts packaged as system commands: gitHttpsToSsh,
  # pull, resetnet. Pure system feature with no user-level deps.
  flake.featureMeta."custom-scripts" = {
    requires = [];
    kind = "cli";
    provides.systemBins = ["gitHttpsToSsh" "pull" "resetnet"];
  };

  # feature test: fully covered by `provides` — no extra script needed.
  flake.featureTests."custom-scripts" = {};
}
