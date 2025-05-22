{ config, pkgs, ... }:

let
  # Define the script as a text file.
  gitHttpsToSsh = pkgs.writeShellScriptBin "gitHttpsToSsh" (builtins.readFile ./gitHttpsToSsh);
  pull = pkgs.writeShellScriptBin "pull" (builtins.readFile ./pull);
in
{
  home.packages = [
    gitHttpsToSsh
    pull
  ];
}
