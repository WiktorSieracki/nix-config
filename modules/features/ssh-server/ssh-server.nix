{
  # Which accounts accept which public keys is identity data — it lives in
  # flake.meta.users.<login>.authorizedKeys and the host loader applies it.
  # This feature is only the sshd service itself.
  #
  # Port 22 is opened only on tailscale0: every machine is reached over the
  # tailnet (`ssh laptop`, `nh os switch --target-host`), so nothing needs
  # sshd on a public or shared network (eduroam, hotel wifi, the VPS's IP).
  flake.modules.nixos.ssh-server = {
    services.openssh = {
      enable = true;
      openFirewall = false;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "no";
      };
    };
    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [22];
  };

  flake.featureMeta.ssh-server = {
    requires = ["tailscale"];
    kind = "service";
    provides = {
      units = ["sshd.service"];
      ports = [22];
    };
  };

  # feature test: `provides` covers sshd listening; this pins the firewall
  # rule — 22 accepted on tailscale0 only, not in the global INPUT allow list.
  flake.featureTests.ssh-server.testScript = ''
    rules = machine.succeed("iptables-save")
    assert "-i tailscale0 -p tcp -m tcp --dport 22 -j nixos-fw-accept" in rules, rules
    assert "-A nixos-fw -p tcp -m tcp --dport 22 -j nixos-fw-accept" not in rules, rules
  '';
}
