{
  # Graphical-session layer extracted from the old `nixos` base bucket so that
  # `core` (the slimmed `flake.modules.nixos.nixos`) stays truly minimal. This
  # makes the modularity litmus test real: a `cli`/`service` feature's Próba runs
  # on `core` alone, so if it secretly needed the niri desktop the test fails.
  #
  # Hosts that want a GUI enable "desktop"; it `requires` "niri" (the compositor
  # that `defaultSession` points at) — the loader hard-fails otherwise.
  flake.modules.nixos.desktop = {pkgs, ...}: {
    services.xserver.enable = true;
    services.displayManager.gdm.enable = true;
    services.displayManager.defaultSession = "niri";

    environment.systemPackages = with pkgs; [
      nautilus
      libreoffice-fresh
      qalculate-gtk
      evince
      file-roller
      vlc
      gnome-disk-utility
      pinta
    ];
  };

  flake.featureMeta.desktop = {
    requires = ["niri"];
    kind = "service";
  };

  # Próba: the desktop layer is present (display-manager exists — the opposite of
  # core-smoke) and the niri session it points at is installed.
  flake.probaTests.desktop = {
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("systemctl cat display-manager.service")
      machine.succeed("command -v niri")
    '';
  };
}
