{ config, pkgs, ... }:

let
  # Define the script as a text file.
  gitHttpsToSsh = pkgs.writeShellScriptBin "gitHttpsToSsh" (builtins.readFile ./gitHttpsToSsh);
in
{
  home.packages = [
    gitHttpsToSsh
  ];
}
