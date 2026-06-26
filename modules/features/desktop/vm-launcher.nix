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
        # Ephemeral disk: a fresh throwaway overlay per launch, deleted on exit.
        # The VM exists to test config reproducibility, so every boot must start
        # clean — no persisted guest state across runs.
        img="$(mktemp -u --tmpdir nixos-vm-test.XXXXXX.qcow2)"
        trap 'rm -f "$img"' EXIT
        export NIX_DISK_IMAGE="$img"
        export SDL_VIDEODRIVER=wayland
        # virgl GL display + a pipewire-backed HD-Audio card so the guest has
        # sound (host runs pipewire). hda-duplex = line-out + mic.
        export QEMU_OPTS="-m 4096 -smp 4 -vga none -device virtio-vga-gl -display sdl,gl=on \
          -audiodev pipewire,id=snd0 -device ich9-intel-hda -device hda-duplex,audiodev=snd0"
        # No `exec` — keep the shell alive so the EXIT trap removes the overlay.
        nix run "$flake#nixosConfigurations.vm.config.system.build.vm"
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
