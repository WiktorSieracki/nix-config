{
  flake.meta = {
    programs = {
      editor = "code";
      terminal = "ghostty";
      browser = "firefox";
      chromium-browser = "brave";
      fileManager = "nautilus";
    };

    # Account identities (ADR 0004). An account exists on a host ⇔ its login is
    # a key of that host's `users` section in features.json; the loader
    # (hosts/configurations.nix) creates it, reading the data from here. User
    # features receive this attrset injected as `userMeta` (+ `login`) into their
    # home-manager evaluation and hardcode no login.
    #
    # Fields: fullName (git user.name), displayName (GECOS — the label the SDDM
    # greeter shows for the account; defaults to fullName), groups, shell (package name),
    # emailSecret / passwordSecret (secret names in secrets.yaml; the password as
    # a hash from `mkpasswd -m sha-512`), authorizedKeys (sshd public keys).
    users = {
      wiktor = {
        fullName = "Wiktor Sieracki";
        # Both accounts belong to the same person, so a bare fullName made the
        # greeter show two identical entries. displayName disambiguates them
        # there without touching the git identity (fullName).
        displayName = "Wiktor Sieracki (Personal)";
        groups = ["networkmanager" "wheel"];
        shell = "fish";
        emailSecret = "studentEmail";
        authorizedKeys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPDwctBSDTMy2mf8LC0WKXnEbYl5mlBLGmtmEJNBpNXR"
        ];
      };

      # Work account: separation of data and identity from `wiktor` (no wheel,
      # homeMode 700 from the NixOS default). Managed by wiktor.
      work = {
        fullName = "Wiktor Sieracki";
        displayName = "Wiktor Sieracki (Work)";
        groups = [];
        shell = "fish";
        emailSecret = "workEmail";
        passwordSecret = "workPasswordHash";
      };
    };
  };
}
