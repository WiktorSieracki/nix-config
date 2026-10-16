{
  # The machine's display name, next to its `networking.hostName`. systemd's
  # PRETTY_HOSTNAME is what tools reach for when they show a machine to a
  # person: `hostnamectl`, Bluetooth's adapter alias, and T3 Code, which labels
  # this host's environment with it and falls back to the bare hostname
  # ("desktopNixos") without it. Host-level because it names this machine.
  # NixOS has no option for it, but points systemd-hostnamed at
  # `/etc/static/machine-info`, so `environment.etc` is the intended route.
  #
  # T3 Code reads it when the server starts and copies it into a client when
  # the client pairs, so after a change: restart `t3code.service`, then re-pair
  # the app (features/apps/t3code/notes.md).
  flake.modules.nixos."hosts/desktopNixos" = {
    environment.etc."machine-info".text = ''
      PRETTY_HOSTNAME="Desktop"
    '';
  };
}
