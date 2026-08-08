{
  self,
  inputs,
  config,
  ...
}: let
  terminal = config.flake.meta.programs.terminal;
in {
  flake.modules.nixos.niri = {pkgs, ...}: {
    programs.niri = {
      enable = true;
      package = self.packages.${pkgs.stdenv.hostPlatform.system}.myNiri;
    };

    xdg.portal = {
      enable = true;
      extraPortals = with pkgs; [
        xdg-desktop-portal-wlr
        xdg-desktop-portal-gtk
        xdg-desktop-portal-gnome
      ];
      config.niri = {
        # Screenshot stays on wlr: it grabs without an interactive picker.
        "org.freedesktop.impl.portal.Screenshot" = ["wlr"];
        # ScreenCast must be gnome. niri implements the org.gnome.Mutter.ScreenCast
        # D-Bus API that xdg-desktop-portal-gnome drives; xdg-desktop-portal-wlr
        # hands out a stream that never advances past its first frame, which is
        # what makes Discord/Firefox screen shares look like a still image.
        # See notes.md.
        "org.freedesktop.impl.portal.ScreenCast" = ["gnome"];
      };
    };

    # niri's `Print` screenshot action puts the PNG on the Wayland clipboard,
    # but only Wayland-native apps can read it back through the protocol.
    # Terminal programs shell out instead: Claude Code runs
    # `wl-paste --type image/png` (falling back to `xclip`), so without
    # wl-clipboard on PATH an image paste silently yields an empty clipboard.
    environment.systemPackages = [pkgs.wl-clipboard];
  };

  perSystem = {
    pkgs,
    lib,
    self',
    ...
  }: let
    extraBinds =
      lib.foldl' (acc: fn: acc // fn {inherit pkgs lib;}) {}
      (builtins.attrValues config.flake.niriBinds);
    extraWindowRules =
      map (fn: fn {inherit pkgs lib;})
      (builtins.attrValues config.flake.niriWindowRules);
  in {
    packages.myNiri = inputs.wrapper-modules.wrappers.niri.wrap {
      inherit pkgs;
      v2-settings = true;
      settings = {
        spawn-at-startup = [
          (lib.getExe self'.packages.myNoctalia)
          "${pkgs.writeShellScript "ghostty-server" "exec ${lib.getExe pkgs.${terminal}} --gtk-single-instance=true --initial-window=false"}"
        ];
        prefer-no-csd = _: {};
        xwayland-satellite.path = lib.getExe pkgs.xwayland-satellite;
        input = {
          keyboard.xkb.layout = "pl";
          mouse = {
            # TUNABLE: pointer speed. Range -1.0 (slowest) .. 1.0 (fastest).
            # 0.0 = niri's default feel; go negative to slow the cursor down.
            # (For hardware sensitivity, lower the G502 DPI via piper/ratbagctl.)
            # Reload live: niri msg action load-config-file
            accel-speed = 0.0;
          };
          touchpad = {
            tap = _: {};
            natural-scroll = _: {};
          };
        };
        layout.gaps = 5;
        layout.background-color = "transparent";

        layout = {
          always-center-single-column = _: {};
        };

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

        workspaces = config.flake.niriWorkspaces;

        window-rules =
          extraWindowRules
          ++ [
            {
              matches = [{app-id = "code";}];
              default-column-width = {
                proportion = 1.0;
              };
            }
            {
              matches = [{app-id = "qalculate-gtk";}];
              open-floating = true;
            }
          ];

        layer-rules = [
          {
            matches = [{namespace = "^noctalia-wallpaper";}];
            place-within-backdrop = true;
          }
        ];

        binds =
          extraBinds
          // {
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

  # Wayland compositor. kind `gui`: niri binary on PATH + Wayland session
  # registered with GDM. No other feature is required (self-sufficient).
  flake.featureMeta.niri = {
    requires = [];
    kind = "gui";
    # Screenshot-to-clipboard is only half a flow: non-Wayland consumers (Claude
    # Code, and anything else shelling out) need wl-paste to read the image
    # back. Guard both halves of wl-clipboard.
    provides.systemBins = ["niri" "wl-paste" "wl-copy"];
  };

  # feature test: we don't launch the compositor (headless VM has no GPU), so
  # the binaries `provides` names carry the Tier-1 assertion; the script pins
  # the portal routing on top.
  flake.featureTests.niri = {
    testScript = ''
      # ScreenCast routed anywhere but gnome yields a frozen first frame on
      # niri, so pin the portal routing that makes screen sharing live.
      machine.succeed(
          "grep -qx 'org.freedesktop.impl.portal.ScreenCast=gnome' "
          "/etc/xdg/xdg-desktop-portal/niri-portals.conf"
      )
    '';
  };
}
