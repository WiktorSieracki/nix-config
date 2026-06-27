{
  # Ghostty itself (the package + Mod+Return bind + TERM) lives in terminal.nix,
  # which is always-on. This module adds the one piece that lets noctalia theme
  # it: a declarative config that points ghostty at the noctalia-generated theme.
  #
  # Noctalia's `ghostty` template (enabled in noctalia.nix) writes the active
  # color scheme to ~/.config/ghostty/themes/noctalia at runtime, then its
  # post-hook ensures the config contains `theme = noctalia` and signals ghostty
  # (SIGUSR2) to live-reload. Because we ship that line here, the post-hook never
  # has to write into this read-only nix symlink — it just triggers the reload.
  #
  # `themes/` stays a real, writable directory (home-manager only symlinks the
  # `config` leaf), so noctalia can create/overwrite themes/noctalia freely.
  flake.modules.homeManager.homeManager = {
    xdg.configFile."ghostty/config".text = ''
      theme = noctalia
    '';
  };
}
