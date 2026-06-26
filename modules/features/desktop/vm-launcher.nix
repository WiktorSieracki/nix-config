# Launcher entry to boot the `vm` host in a *windowed* QEMU (not full-screen),
# so it shows up in the app launcher (Mod+Space) instead of needing a keybind.
# Same SDL/virgl invocation as the CLAUDE.md command, minus `-full-screen`.
{
  flake.modules.homeManager.homeManager = {
    pkgs,
    lib,
    ...
  }: let
    runVm = pkgs.writeShellApplication {
      name = "run-vm-windowed";
      text = ''
        flake=/home/wiktor/.config/nix-config
        # Keep the scratch overlay (vm-vm.qcow2) out of the repo; state persists
        # across runs — delete it for a clean boot.
        statedir="''${XDG_STATE_HOME:-$HOME/.local/state}/nixos-vm"
        mkdir -p "$statedir"
        cd "$statedir"
        export SDL_VIDEODRIVER=wayland
        export QEMU_OPTS="-m 4096 -smp 4 -vga none -device virtio-vga-gl -display sdl,gl=on"
        exec nix run "$flake#nixosConfigurations.vm.config.system.build.vm"
      '';
    };
  in {
    home.packages = [runVm];

    # Wrapped in a terminal so the build/boot output (and any error) is visible.
    xdg.desktopEntries.run-vm-windowed = {
      name = "NixOS VM (windowed)";
      genericName = "QEMU VM";
      comment = "Boot the `vm` host in a windowed QEMU — Ctrl+Alt+G to grab keyboard/mouse";
      icon = "computer";
      exec = "${lib.getExe pkgs.ghostty} -e ${lib.getExe runVm}";
      terminal = false;
      categories = ["Development" "System"];
      settings.Keywords = "qemu;vm;nixos;test;virtual;";
    };
  };
}
