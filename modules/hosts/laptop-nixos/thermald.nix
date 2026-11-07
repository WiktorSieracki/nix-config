{
  # Intel's thermal daemon: keeps the CPU under its trip points by throttling
  # gradually (RAPL, P-states) instead of letting the firmware hard-throttle
  # or shut down. Intel-only, hence host-level rather than a feature. It works
  # alongside power-profiles-daemon from the core floor.
  flake.modules.nixos."hosts/laptopNixos" = {
    services.thermald.enable = true;
  };
}
