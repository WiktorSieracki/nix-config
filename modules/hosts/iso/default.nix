{
  lib,
  config,
  ...
}: let
  # The ISO is a *minimal installer*, not a live desktop.
  #
  # Everything the real machines run is fetched at install time by
  # `nixos-install --flake github:WiktorSieracki/nix-config#desktopNixos`, so
  # baking niri/firefox/vscode into the image never made an install faster --
  # it only inflated the image to ~4.2 GB, which in turn forced splitting the
  # GitHub release into sub-2-GiB parts. The image now carries just enough to
  # partition a disk, get networking up and run `nixos-install`.
  #
  # What stays and why:
  #   - `nix`  -- enables `experimental-features = nix-command flakes`, without
  #               which `nixos-install --flake` refuses to run. Brings `nh` too.
  #   - `fish` -- the shell actually typed into on the installer console.
  #
  # Plain `pkgs.git` is added below instead of the `git` feature: that feature
  # has `requires = ["sops"]` (user.email comes from a SOPS template) and the
  # live image has no key.
  isoSpec = {
    system = ["nix"];
    users.wiktor = ["fish"];
  };
in {
  flake.nixosConfigurations.iso = lib.nixosSystem {
    system = "x86_64-linux";
    modules =
      [
        # The stock NixOS minimal installer: bootloader, squashfs root, console
        # autologin, networking, sshd, nixos-install, partitioning tools.
        # `installation-cd-minimal.nix` layers `profiles/minimal.nix` on top of
        # the base installer (no docs/info, no udisks2, empty
        # `environment.defaultPackages`) -- all `mkDefault`, so the modules
        # below still win.
        ({modulesPath, ...}: {
          imports = [
            (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
          ];
        })

        # The core floor: locale, `console.keyMap = "pl2"`, timezone and
        # NetworkManager (so `nmtui` is on hand to get WiFi up before
        # installing). No graphical session -- that lives in the `desktop`
        # feature, which this image deliberately does not enable.
        config.flake.modules.nixos.nixos

        ({pkgs, ...}: {
          networking.hostName = "nixos-iso";
          nixpkgs.hostPlatform = "x86_64-linux";
          system.stateVersion = "24.11";

          # The core floor waits "forever" at the bootloader; the ISO module
          # wants 10s. Both set it at normal priority, so pick one.
          boot.loader.timeout = lib.mkForce 10;

          # `nixos-install --flake github:...` fetches the flake with git.
          environment.systemPackages = [pkgs.git];

          # Pull side of the personal cache, so the closure CI built for
          # desktopNixos/laptopNixos is substituted here instead of rebuilt.
          # The `cachix` feature carries these same two settings but is
          # unusable on this image: it `requires = ["sops"]` for its *push*
          # token, and the live image has no key.
          nix.settings.substituters = ["https://wiktor-nixos.cachix.org"];
          nix.settings.trusted-public-keys = [
            "wiktor-nixos.cachix.org-1:3DOZHbBhM0h+YZFUZ1zZikBSLC7cTbZglgQEhF7Gi2M="
          ];

          # Password set so the install procedure can SSH into the live image
          # as `wiktor`/`nixos` and sudo once inside.
          users.users.wiktor.initialPassword = "nixos";

          # The installer profile autologins its own `nixos` account on tty1;
          # land in wiktor's fish instead.
          services.getty.autologinUser = lib.mkForce "wiktor";
        })
      ]
      ++ config.flake.lib.loadHost config isoSpec;
  };
}
