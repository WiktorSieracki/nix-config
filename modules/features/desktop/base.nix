{
  flake.niriBinds.nautilus = {pkgs, lib}: {
    "Mod+E" = _: {
      props."hotkey-overlay-title" = "Open file manager: Nautilus";
      content."spawn" = "${lib.getExe pkgs.nautilus}";
    };
  };

  flake.modules.nixos.nixos = {pkgs, ...}: {
    networking.networkmanager.enable = true;
    hardware.bluetooth.enable = true;
    services.power-profiles-daemon.enable = true;
    services.upower.enable = true;
    programs.nix-ld.enable = true;

    services.xserver.enable = true;
    services.displayManager.gdm.enable = true;
    services.displayManager.defaultSession = "niri";

    environment.systemPackages = with pkgs; [
      tree
      treecat
      tealdeer
      neovim
      nautilus
      libreoffice-fresh
      qalculate-gtk
      evince
      file-roller
      p7zip
      vlc
      gnome-disk-utility
      pinta
    ];
  };
}
