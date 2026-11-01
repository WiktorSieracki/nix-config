{
  # The VPS decrypts with its own ssh host key, not wiktor's personal one, and
  # only from secrets-vps.yaml — the few secrets this host's features use. So a
  # compromised VPS leaks neither wiktor's key nor the main secrets.yaml
  # (eduroam, wifi, the work account). The host key's private half is kept
  # in secrets-vps.yaml as `vpsHostKey` (no plaintext copy anywhere), and the
  # install puts it in place before the first boot (notes.md).
  flake.modules.nixos."hosts/vpsNixos" = {lib, ...}: {
    sops = {
      defaultSopsFile = lib.mkForce ../../../secrets-vps.yaml;
      age.sshKeyPaths = lib.mkForce ["/etc/ssh/ssh_host_ed25519_key"];
    };
  };
}
