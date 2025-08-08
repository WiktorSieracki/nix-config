{ config, pkgs, ... }:

let
  # Get the path to the current directory
  scriptDir = ./.;

  # Define the script as a text file.
  gitHttpsToSsh = pkgs.writeShellScriptBin "gitHttpsToSsh" (
    builtins.readFile (scriptDir + /gitHttpsToSsh)
  );
  pull = pkgs.writeShellScriptBin "pull" (builtins.readFile (scriptDir + /pull));
  manage = pkgs.writeShellScriptBin "manage" (builtins.readFile (scriptDir + /manage));
in
{
  home.packages = [
    gitHttpsToSsh
    pull
    manage
  ];
}
