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
}
