{ inputs, pkgs, ... }:

{
  programs.firefox = {
    enable = true;

    profiles.default = {
      # Firefox extensions
      extensions.packages = with inputs.firefox-addons.packages."x86_64-linux"; [
        bitwarden
        ublock-origin
        sponsorblock
        vimium-c
        darkreader
      ];

    };
  };
}
