{
  # Nothing listens on the public IP: sshd is reachable only over the tailnet
  # (t3code already is, via Tailscale Serve). The `ssh-server` feature opens
  # 22 everywhere, so the host takes that back and reopens it on tailscale0.
  #
  # Lockout recovery if tailscaled ever breaks: Hetzner console → Rescue →
  # boot the rescue system, mount /dev/sda3 and fix it, or roll back to the
  # previous generation from the GRUB menu in the web console (wiktor has no
  # password, so the console itself cannot log in). Deploy over the tailnet:
  # `nh os switch -H vpsNixos --target-host vps-nixos`.
  flake.modules.nixos."hosts/vpsNixos" = {lib, ...}: {
    services.openssh.openFirewall = lib.mkForce false;
    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [22];
  };
}
