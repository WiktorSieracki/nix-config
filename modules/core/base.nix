{
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
