{ inputs, pkgs, ... }:

{
  programs.firefox = {
    enable = true;

    profiles.default = {
      # Firefox extensions
      extensions.packages = with inputs.firefox-addons.packages.${pkgs.system}; [
        bitwarden
        ublock-origin
        sponsorblock
        vimium-c
        darkreader
      ];
      settings = {
        "extensions.autoDisableScopes" = 0; # Disable auto-disabling of extensions
      };

    };
  };
}
