{
  # Display name next to `networking.hostName`; T3 Code labels this host's
  # environment with it (see desktop-nixos/pretty-hostname.nix).
  flake.modules.nixos."hosts/vpsNixos" = {
    environment.etc."machine-info".text = ''
      PRETTY_HOSTNAME="VPS"
    '';
  };
}
