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
  isoModules = [
    # system
    "wiktor"
    "niri"

    # shell & environment
    "fish"
    "nix"

    # development
    "vscode"
    "python"
    "nodejs"

    # apps
    "firefox"
    "localsend"
  ];
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
          # Bring the base home-manager profile into wiktor's HM, mirroring how
          # the real hosts are assembled in hosts/configurations.nix.
          home-manager.users.wiktor.imports = [
            config.flake.modules.homeManager.homeManager
          ];

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
      ++ config.flake.lib.loadNixosAndHmModuleForUser config isoModules;
  };
}
