{
  self,
  inputs,
  ...
}: {
  flake.homeModules.firefox = {pkgs, ...}: {
    programs.firefox = {
      enable = true;
      profiles.wiktor = {
        search.engines = {
          "Nix Packages" = {
            urls = [
              {
                template = "https://search.nixos.org/packages";
                params = [
                  {
                    name = "type";
                    value = "packages";
                  }
                  {
                    name = "query";
                    value = "{searchTerms}";
                  }
                ];
              }
            ];

            icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
            definedAliases = ["@np"];
          };
        };
        search.force = true;

        bookmarks = {
          force = true;
          settings = [
            {
              name = "toolbar";
              toolbar = true;
              bookmarks = [
                {
                  name = "Personal Page";
                  url = "https://wiktorsieracki.com";
                }
                # {
                #   name = "folder";
                #   bookmarks = [
                #     {
                #       name = "Nix Packages";
                #       url = "https://search.nixos.org/packages";
                #     }
                #   ];
                # }
              ];
            }
          ];
        };

        settings = {
          "dom.security.https_only_mode" = true;
          "browser.download.panel.shown" = true;
          "identity.fxaccounts.enabled" = false;
          # "signon.rememberSignons" = false;
        };

        userChrome = ''
          /* some css */
        '';

        extensions.packages = with inputs.firefox-addons.packages."x86_64-linux"; [
          bitwarden
          ublock-origin
          sponsorblock
          darkreader
          vimium-c
          pywalfox
          # tridactyl
          # youtube-shorts-block
        ];
      };
    };
  };
}
