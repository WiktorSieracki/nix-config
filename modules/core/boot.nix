{
  flake.modules.nixos.nixos = {
    boot.loader = {
      efi.canTouchEfiVariables = true;
      grub = {
        enable = true;
        devices = ["nodev"];
        efiSupport = true;
        useOSProber = true;
        # Each generation copies its kernel+initrd onto the ESP; cap the menu
        # so old ones get pruned instead of slowly filling the partition.
        configurationLimit = 10;
      };
      timeout = 10;
    };
  };
}
