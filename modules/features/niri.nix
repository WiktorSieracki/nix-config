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
      settings = {
        spawn-at-startup = [
          (lib.getExe self'.packages.myNoctalia)
        ];
        xwayland-satellite.path = lib.getExe pkgs.xwayland-satellite;
        input.keyboard.xkb.layout = "us,pl";
        layout.gaps = 5;

        outputs."HP Inc. HP E243 CNC0171FR8" = {
          mode = "1920x1080@60.000";
          "position x=0 y=0" = null;
        };
        outputs."Ancor Communications Inc ASUS VX239 G6LMTJ040329" = {
          mode = "1920x1080@60.000";
          "position x=1920 y=0" = null;
        };

        window-rules = [
          {
            matches = [{app-id = "Code";}];
            default-column-width = {proportion = 1.0;};
          }
        ];

        binds = {
          "Mod+C hotkey-overlay-title=\"Open nix-config in an editor\"".spawn-sh = "code ~/.config/nix-config";
          "Mod+A hotkey-overlay-title=\"Open gemini in Firefox\"".spawn = ["${lib.getExe pkgs.firefox}" "--new-window" "https://gemini.google.com"];
          "Mod+B hotkey-overlay-title=\"Open a Browser: Firefox\"".spawn = "${lib.getExe pkgs.firefox}";

          "Mod+Return".spawn-sh = lib.getExe pkgs.alacritty;
          "Mod+W repeat=false".close-window = null;
          "Mod+Space".spawn-sh = "${lib.getExe self'.packages.myNoctalia} ipc call launcher toggle";
          "Mod+F".maximize-column = null;
          "Mod+O repeat=false".toggle-overview = null;

          "Mod+Shift+Slash".show-hotkey-overlay = null;

          "Mod+H".focus-column-left = null;
          "Mod+L".focus-column-right = null;
          "Mod+K".focus-window-up = null;
          "Mod+J".focus-window-down = null;

          "Mod+Left".focus-column-left = null;
          "Mod+Right".focus-column-right = null;
          "Mod+Up".focus-window-up = null;
          "Mod+Down".focus-window-down = null;

          "Mod+Shift+H".move-column-left = null;
          "Mod+Shift+L".move-column-right = null;
          "Mod+Shift+K".move-window-up = null;
          "Mod+Shift+J".move-window-down = null;

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

          "Mod+WheelScrollDown cooldown-ms=150".focus-workspace-down = null;
          "Mod+WheelScrollUp cooldown-ms=150".focus-workspace-up = null;
          "Mod+WheelScrollRight".focus-column-right = null;
          "Mod+WheelScrollLeft".focus-column-left = null;

          "Mod+Shift+WheelScrollDown cooldown-ms=150".move-column-to-workspace-down = null;
          "Mod+Shift+WheelScrollUp cooldown-ms=150".move-column-to-workspace-up = null;
          "Mod+Shift+WheelScrollRight".move-column-right = null;
          "Mod+Shift+WheelScrollLeft".move-column-left = null;

          "Mod+Shift+E".quit = null;
          "Ctrl+Alt+Delete".quit = null;
        };
      };
    };
  };
}
