{
  lib,
  config,
  ...
}: let
  # Same curated subset as the ISO host: niri desktop + a handful of apps,
  # minus hardware-specific (nvidia/wacom/mouse) and secret-dependent
  # (sops/git/personal-snippets/eduroam/home-wifi) modules.
  vmSpec = {
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
      # Without it swaybg (spawned by niri) points at a wallpaper that doesn't
      # exist in a fresh home, so the VM boots to a bare desktop.
      "wallpapers"
    ];
    # The work account, so switching to it can be exercised in the VM. Its
    # real feature list needs secrets (git email template, …), so this is the
    # same secret-free subset as wiktor's.
    users.work = [
      "fish"
      "vscode"
      "firefox"
      "wallpapers"
    ];
  };
in {
  # A normal, bootable host used purely to produce disk images
  # (`nh os build-image -H vm --image-variant qemu-efi`). Unlike the `iso`
  # host it has no live-CD module, so `system.build.images.*` works.
  flake.nixosConfigurations.vm = lib.nixosSystem {
    system = "x86_64-linux";
    modules =
      [
        config.flake.modules.nixos.nixos

        {
          networking.hostName = "nixos-vm";
          nixpkgs.hostPlatform = "x86_64-linux";
          system.stateVersion = "24.11";

          # The shared base config installs GRUB-EFI and writes EFI variables,
          # which a sandboxed image build can't do and which collides with the
          # disk-image format's own bootloader. Use systemd-boot into the ESP
          # the image provides, and never touch efivars.
          boot.loader.grub.enable = lib.mkForce false;
          boot.loader.systemd-boot.enable = lib.mkForce true;
          boot.loader.efi.canTouchEfiVariables = lib.mkForce false;
          boot.loader.timeout = lib.mkForce 5;

          # ghostty's OpenGL renderer can't get a working GL context under the
          # nested virgl (virtio-vga-gl) path, so `Mod+Return` opens nothing in
          # the VM. Forcing mesa's llvmpipe (software GL) makes it render. Scoped
          # to this throwaway test host only — real hardware hosts keep native GL.
          environment.sessionVariables.LIBGL_ALWAYS_SOFTWARE = "1";

          # Log straight into wiktor's niri session; password set for sudo.
          users.users.wiktor.initialPassword = "nixos";
          # work's real password comes from sops (absent here), so give it the
          # same throwaway password to make the SDDM login usable.
          users.users.work.initialPassword = "nixos";
          services.displayManager.autoLogin = {
            enable = true;
            user = "wiktor";
          };
        }
      ]
      ++ config.flake.lib.loadHost config vmSpec;
  };
}
