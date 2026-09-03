{
  # Boot straight into wiktor's niri session instead of stopping at the SDDM
  # greeter. Host-level, not a feature: "trust whoever is physically at this
  # machine" is a per-machine policy, and the option names a login — the thing
  # features are explicitly built not to hardcode (ADR 0004). The vm and iso
  # hosts set it the same way.
  #
  # Toggle: flip `enable` (or delete this file) and reboot.
  flake.modules.nixos."hosts/desktopNixos" = {
    # `sddm.autoLogin.relogin` stays at its upstream default `false`, so this
    # only fires when display-manager *starts*. Logging out drops you back at
    # the greeter — that is how the `work` account stays reachable without
    # turning autologin off.
    services.displayManager.autoLogin = {
      enable = true;
      user = "wiktor";
    };
  };
}
