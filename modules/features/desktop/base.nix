{
  flake.niriBinds.nautilus = {pkgs, lib}: {
    "Mod+E" = _: {
      props."hotkey-overlay-title" = "Open file manager: Nautilus";
      content."spawn" = "${lib.getExe pkgs.nautilus}";
    };
  };

  # Nautilus opens as a centred floating popup rather than a tiled column.
  # niri centres new floating windows by default, so only the size is declared.
  flake.niriWindowRules.nautilus = _: {
    matches = [{app-id = "^org\\.gnome\\.Nautilus$";}];
    open-floating = true;
    default-column-width.proportion = 0.5;
    default-window-height.proportion = 0.6;
  };

  # Core floor: the irreducible system substrate present in every host and every
  # feature test. Deliberately holds NO graphical session and NO GUI apps — those moved
  # to the `desktop` feature (see desktop.nix) so the modularity litmus test
  # ("does this feature work without niri?") is actually meaningful.
  flake.modules.nixos.nixos = {pkgs, ...}: {
    networking.networkmanager.enable = true;

    # Admin policy for `wheel` accounts (who is in wheel lives per account in
    # flake.meta.users.<login>.groups). Was part of the dissolved `wiktor`
    # foundation feature (ADR 0004).
    security.sudo.wheelNeedsPassword = false;
    hardware.bluetooth.enable = true;
    services.power-profiles-daemon.enable = true;
    services.upower.enable = true;
    programs.nix-ld.enable = true;

    environment.systemPackages = with pkgs; [
      tree
      treecat
      tealdeer
      neovim
      p7zip
    ];
  };
}
