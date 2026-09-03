{
  flake.modules.nixos.nixos = {
    boot.loader = {
      efi.canTouchEfiVariables = true;
      grub = {
        enable = true;
        devices = ["nodev"];
        efiSupport = true;
        useOSProber = true;
      };
      timeout = 10;
    };
  };
}
