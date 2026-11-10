{
  flake.meta = {
    programs = {
      editor = "code";
      terminal = "ghostty";
      browser = "firefox";
      chromium-browser = "brave";
      fileManager = "nautilus";
    };

    # Account identities. An account exists on a host ⇔ the host's spec lists
    # its login in `users` (hosts/<host>/default.nix); the loader
    # (hosts/configurations.nix) creates it, reading the data from here. A
    # feature's home-manager part receives this attrset injected as `userMeta`
    # (+ `login`) and hardcodes no login.
    #
    # Fields: fullName (git user.name), displayName (GECOS — the label the SDDM
    # greeter shows for the account; defaults to fullName), groups, shell (package name),
    # emailSecret / passwordSecret (secret names in secrets.yaml; the password as
    # a hash from `mkpasswd -m sha-512`), authorizedKeys (sshd public keys).
    users = {
      wiktor = {
        fullName = "Wiktor Sieracki";
        groups = ["networkmanager" "wheel"];
        shell = "fish";
        emailSecret = "personalEmail";
        authorizedKeys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPDwctBSDTMy2mf8LC0WKXnEbYl5mlBLGmtmEJNBpNXR"
        ];
      };

      # Sandbox identity (Tier-1-live). Exists only inside the throwaway
      # `sandbox-*` VMs, never on a real host: the live sandbox runs features on
      # a neutral account for the same reason the feature tests do — a feature
      # that hardcodes someone's login must fail there instead of passing
      # because the tester happened to be called `wiktor`.
      tester = {
        fullName = "Sandbox Tester";
        displayName = "Sandbox";
        # `ydotool` is what lets the agent synthesise clicks in the guest
        # (programs.ydotool gates its socket on that group). No `shell` on
        # purpose: the runner drives this account over ssh, and a login shell
        # with fish's syntax would break plain `sh -c` command lines.
        groups = ["wheel" "networkmanager" "video" "input" "ydotool"];
        authorizedKeys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPDwctBSDTMy2mf8LC0WKXnEbYl5mlBLGmtmEJNBpNXR"
        ];
      };
    };
  };
}
