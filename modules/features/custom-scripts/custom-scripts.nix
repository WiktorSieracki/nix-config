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
  };

  # feature test: at least one script is on PATH and executable.
  flake.featureTests."custom-scripts" = {
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("command -v gitHttpsToSsh")
      machine.succeed("command -v pull")
      machine.succeed("command -v resetnet")
    '';
  };
}
