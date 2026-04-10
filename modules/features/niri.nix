{
  self,
  inputs,
  ...
}: {
  flake.modules.nixos.niri = {pkgs, ...}: {
    programs.niri = {
      enable = true;
      package = self.packages.${pkgs.stdenv.hostPlatform.system}.myNiri;
    };
  };

  perSystem = {
    pkgs,
    lib,
    self',
    ...
  }: {
    packages.myNiri = inputs.wrapper-modules.wrappers.niri.wrap {
      inherit pkgs;
      v2-settings = true;
      settings = {
        spawn-at-startup = [
          (lib.getExe self'.packages.myNoctalia)
        ];
        prefer-no-csd = _: {};
        xwayland-satellite.path = lib.getExe pkgs.xwayland-satellite;
        input = {
          keyboard.xkb.layout = "pl";
          touchpad = {
            tap = _: {};
            natural-scroll = _: {};
          };
        };
        layout.gaps = 5;
        layout.background-color = "transparent";

        outputs."HP Inc. HP E243 CNC0171FR8" = {
          mode = "1920x1080@60.000";
          position = _: {
            props = {
              x = 0;
              y = 0;
            };
          };
        };
        outputs."Ancor Communications Inc ASUS VX239 G6LMTJ040329" = {
          mode = "1920x1080@60.000";
          position = _: {
            props = {
              x = 1920;
              y = 0;
            };
          };
        };

        window-rules = [
          {
            matches = [{app-id = "code";}];
            default-column-width = {
              proportion = 1.0;
            };
          }
        ];

        layer-rules = [
          {
            matches = [{namespace = "^noctalia-wallpaper";}];
            place-within-backdrop = true;
          }
        ];

        binds = {
          "Mod+C" = _: {
            props = {
              "hotkey-overlay-title" = "Open nix-config in an editor";
            };
            content = {
              "spawn-sh" = "code ~/.config/nix-config";
            };
          };

          "Mod+A" = _: {
            props = {
              "hotkey-overlay-title" = "Open gemini in Firefox";
            };
            content = {
              "spawn" = [
                "${lib.getExe pkgs.firefox}"
                "--new-window"
                "https://gemini.google.com"
              ];
            };
          };
          "Mod+G" = _: {
            props = {
              "hotkey-overlay-title" = "Open gmail in Firefox";
            };
            content = {
              "spawn" = [
                "${lib.getExe pkgs.firefox}"
                "--new-window"
                "https://mail.google.com/mail/u/1/#all"
              ];
            };
          };
          "Mod+Shift+C" = _: {
            props = {
              "hotkey-overlay-title" = "Open calendar in Firefox";
            };
            content = {
              "spawn" = [
                "${lib.getExe pkgs.firefox}"
                "--new-window"
                "https://calendar.google.com/calendar/u/1/r?pli=1"
              ];
            };
          };

          "Mod+N" = _: {
            props = {
              "hotkey-overlay-title" = "Open notion in Firefox";
            };
            content = {
              "spawn" = [
                "${lib.getExe pkgs.firefox}"
                "--new-window"
                "https://www.notion.so"
              ];
            };
          };

          "Mod+S" = _: {
            props = {
              "hotkey-overlay-title" = "Open Spotify";
            };
            content = {
              "spawn" = ["${lib.getExe pkgs.spotify}"];
            };
          };

          "Mod+D" = _: {
            props = {
              "hotkey-overlay-title" = "Open Discord";
            };
            content = {
              "spawn" = ["${lib.getExe pkgs.discord}"];
            };
          };

          "Mod+B" = _: {
            props = {
              "hotkey-overlay-title" = "Open a Browser: Firefox";
            };
            content = {
              "spawn" = "${lib.getExe pkgs.firefox}";
            };
          };

          "Mod+Return".spawn-sh = lib.getExe pkgs.alacritty;

          "Mod+W" = _: {
            props = {
              repeat = false;
            };
            content = {
              "close-window" = _: {};
            };
          };

          "Mod+Space".spawn-sh = "${lib.getExe self'.packages.myNoctalia} ipc call launcher toggle";

          "Mod+F".maximize-column = _: {};

          "Mod+R".spawn-sh = "handy --toggle-transcription";

          "Mod+O" = _: {
            props = {
              repeat = false;
            };
            content = {
              "toggle-overview" = _: {};
            };
          };

          "Mod+P".spawn-sh = "${lib.getExe self'.packages.myNoctalia} ipc call sessionMenu toggle";

          "Mod+Shift+Slash".show-hotkey-overlay = _: {};

          "Mod+H".focus-column-left = _: {};
          "Mod+L".focus-column-right = _: {};
          "Mod+K".focus-window-up = _: {};
          "Mod+J".focus-window-down = _: {};

          "Mod+Left".focus-column-left = _: {};
          "Mod+Right".focus-column-right = _: {};
          "Mod+Up".focus-window-up = _: {};
          "Mod+Down".focus-window-down = _: {};

          "Mod+Shift+H".move-column-left = _: {};
          "Mod+Shift+L".move-column-right = _: {};
          "Mod+Shift+K".move-window-up = _: {};
          "Mod+Shift+J".move-window-down = _: {};

          "Mod+1".focus-workspace = 1;
          "Mod+2".focus-workspace = 2;
          "Mod+3".focus-workspace = 3;
          "Mod+4".focus-workspace = 4;
          "Mod+5".focus-workspace = 5;
          "Mod+6".focus-workspace = 6;
          "Mod+7".focus-workspace = 7;
          "Mod+8".focus-workspace = 8;
          "Mod+9".focus-workspace = 9;

          "Mod+Shift+1".move-column-to-workspace = 1;
          "Mod+Shift+2".move-column-to-workspace = 2;
          "Mod+Shift+3".move-column-to-workspace = 3;
          "Mod+Shift+4".move-column-to-workspace = 4;
          "Mod+Shift+5".move-column-to-workspace = 5;
          "Mod+Shift+6".move-column-to-workspace = 6;
          "Mod+Shift+7".move-column-to-workspace = 7;
          "Mod+Shift+8".move-column-to-workspace = 8;
          "Mod+Shift+9".move-column-to-workspace = 9;

          "Mod+WheelScrollDown" = _: {
            props = {
              "cooldown-ms" = 150;
            };
            content = {
              "focus-workspace-down" = _: {};
            };
          };

          "Mod+WheelScrollUp" = _: {
            props = {
              "cooldown-ms" = 150;
            };
            content = {
              "focus-workspace-up" = _: {};
            };
          };

          "Mod+WheelScrollRight".focus-column-right = _: {};
          "Mod+WheelScrollLeft".focus-column-left = _: {};

          "Mod+Shift+WheelScrollDown" = _: {
            props = {
              "cooldown-ms" = 150;
            };
            content = {
              "move-column-to-workspace-down" = _: {};
            };
          };

          "Mod+Shift+WheelScrollUp" = _: {
            props = {
              "cooldown-ms" = 150;
            };
            content = {
              "move-column-to-workspace-up" = _: {};
            };
          };

          "Mod+Shift+WheelScrollRight".move-column-right = _: {};
          "Mod+Shift+WheelScrollLeft".move-column-left = _: {};

          "Mod+Shift+E".quit = _: {};
          "Ctrl+Alt+Delete".quit = _: {};
          "Print".screenshot = _: {};
        };
      };
    };
  };
}
