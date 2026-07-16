{inputs, ...}: {
  flake.niriBinds.firefox = {pkgs, lib}: {
    "Mod+B" = _: {
      props."hotkey-overlay-title" = "Open a Browser: Firefox";
      content."spawn" = "${lib.getExe pkgs.firefox}";
    };
    "Mod+A" = _: {
      props."hotkey-overlay-title" = "Open claude in Firefox";
      content."spawn" = ["${lib.getExe pkgs.firefox}" "--new-window" "https://claude.ai/new?incognito"];
    };
    "Mod+G" = _: {
      props."hotkey-overlay-title" = "Open gmail in Firefox";
      content."spawn" = ["${lib.getExe pkgs.firefox}" "--new-window" "https://mail.google.com/mail/u/1/#all"];
    };
    "Mod+Shift+C" = _: {
      props."hotkey-overlay-title" = "Open calendar in Firefox";
      content."spawn" = ["${lib.getExe pkgs.firefox}" "--new-window" "https://calendar.google.com/calendar/u/1/r?pli=1"];
    };
    "Mod+N" = _: {
      props."hotkey-overlay-title" = "Open notion in Firefox";
      content."spawn" = ["${lib.getExe pkgs.firefox}" "--new-window" "https://www.notion.so"];
    };
  };

  flake.modules.homeManager.firefox = {pkgs, ...}: {
    programs.firefox = {
      enable = true;
      configPath = ".mozilla/firefox";

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

          "browser.toolbars.bookmarks.visibility" = "always";
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

  flake.featureMeta.firefox = {
    requires = ["desktop"];
    kind = "gui";
  };

  # firefox-addons extensions are fetched from addons.mozilla.org as
  # fixed-output derivations — stub them out in the feature test to avoid
  # marketplace network deps at test-build time.
  flake.featureTests.firefox = {
    extraHmModules = [
      ({lib, ...}: {
        programs.firefox.profiles.wiktor.extensions.packages = lib.mkForce [];
      })
    ];
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("home-manager-tester.service")
      machine.succeed("su - tester -c 'command -v firefox'")
    '';
  };
}
