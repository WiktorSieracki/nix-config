{
  flake.modules.nixos.ssh-server = {
    users.users.wiktor = {
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPDwctBSDTMy2mf8LC0WKXnEbYl5mlBLGmtmEJNBpNXR"
      ];
    };

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

  # ssh-server sets authorizedKeys on the wiktor user, which requires the
  # user to be declared (isNormalUser = true) — that lives in the `wiktor`
  # feature. Without it, NixOS activation fails with
  # "Exactly one of isSystemUser and isNormalUser must be set".
  flake.featureMeta.ssh-server = {
    requires = ["wiktor"];
    kind = "service";
  };

  flake.probaTests.ssh-server = {
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("sshd.service")
    '';
  };
}
