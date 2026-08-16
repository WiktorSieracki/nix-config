{
  lib,
  config,
  ...
}: let
  # Curated subset of features baked into the bootable ISO.
  #
  # Excluded on purpose:
  #   - hardware-specific: nvidia, wacom, mouse (a VM has none of these)
  #   - secret-dependent: sops, git, personal-snippets, eduroam, home-wifi
  #     (the SOPS key from the real machine isn't present on the live image,
  #      so these would fail to activate inside the VM)
  #   - login-walled / heavy apps: discord, spotify, teams, handy, affine, ...
  #
  # Add or remove names here to change what ships on the ISO.
  isoSpec = {
    system = [
      "niri"
      "desktop"
      "nix"
      "python"
      "nodejs"
    ];
    users.wiktor = [
      "fish"
      "vscode"
      "firefox"
      "localsend"
      # Same reason as the vm host: noctalia's startup hook sets a wallpaper
      # path that only this feature puts in the home.
      "wallpapers"
    ];
  };
in {
  flake.nixosConfigurations.iso = lib.nixosSystem {
    system = "x86_64-linux";
    modules =
      [
        # The stock NixOS live/installer image: bootloader, squashfs root,
        # console autologin ("nixos"), networking, sshd, nixos-install, etc.
        ({modulesPath, ...}: {
          imports = [
            (modulesPath + "/installer/cd-dvd/installation-cd-base.nix")
          ];
        })

        # Shared base config used by every host (niri/gdm desktop, locale,
        # sound, networking, default package set). Its GRUB bootloader is
        # automatically disabled by the ISO image module.
        config.flake.modules.nixos.nixos

        {
          networking.hostName = "nixos-iso";
          nixpkgs.hostPlatform = "x86_64-linux";
          system.stateVersion = "24.11";

          # The base host config waits "forever" at the bootloader; the ISO
          # module wants 10s. Both set it at normal priority, so pick one.
          boot.loader.timeout = lib.mkForce 10;

          # Log straight into wiktor's niri session in the VM. Password is set
          # so you can also sudo / unlock once inside.
          users.users.wiktor.initialPassword = "nixos";
          services.displayManager.autoLogin = {
            enable = true;
            user = "wiktor";
          };
        }
      ]
      ++ config.flake.lib.loadHost config isoSpec;
  };
}
