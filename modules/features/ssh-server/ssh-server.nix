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
  };

  flake.probaTests.ssh-server = {
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("sshd.service")
    '';
  };
}
