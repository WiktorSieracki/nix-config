{
  flake.modules.nixos.custom-scripts = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      (writeShellScriptBin "gitHttpsToSsh" (
        builtins.readFile ./gitHttpsToSsh.sh
      ))
      (writeShellScriptBin "pull" (builtins.readFile ./pull.sh))
    ];
  };
}
