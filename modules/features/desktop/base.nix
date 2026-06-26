{
  flake.niriBinds.nautilus = {pkgs, lib}: {
    "Mod+E" = _: {
      props."hotkey-overlay-title" = "Open file manager: Nautilus";
      content."spawn" = "${lib.getExe pkgs.nautilus}";
    };
  };

  # Core floor: the irreducible system substrate present in every host and every
  # Próba. Deliberately holds NO graphical session and NO GUI apps — those moved
  # to the `desktop` feature (see desktop.nix) so the modularity litmus test
  # ("does this feature work without niri?") is actually meaningful.
  flake.modules.nixos.nixos = {pkgs, ...}: {
    networking.networkmanager.enable = true;
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
