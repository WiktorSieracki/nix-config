{
  flake.modules.nixos.nixos = {pkgs, ...}: {
    boot.loader = {
      efi.canTouchEfiVariables = true;
      grub = {
        enable = true;
        devices = ["nodev"];
        efiSupport = true;
        useOSProber = true;
      };
      timeout = 99999; # wait forever
    };
  };
}
