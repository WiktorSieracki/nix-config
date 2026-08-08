{
  # Which accounts accept which public keys is identity data — it lives in
  # flake.meta.users.<login>.authorizedKeys and the host loader applies it.
  # This feature is only the sshd service itself.
  flake.modules.nixos.ssh-server = {
    services.openssh = {
      enable = true;
      openFirewall = true;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "no";
      };
    };
  };

  flake.featureMeta.ssh-server = {
    requires = [];
    kind = "service";
    provides = {
      units = ["sshd.service"];
      ports = [22];
    };
  };

  # feature test: fully covered by `provides` — no extra script needed.
  flake.featureTests.ssh-server = {};
}
