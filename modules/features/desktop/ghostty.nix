{
  # Ghostty itself (the package + Mod+Return bind + TERM) lives in terminal.nix,
  # which is always-on. This module ships its declarative config.
  #
  # The theme is one of ghostty's bundled ones, matching the Gruvbox palette
  # the quickshell UI uses (Theme.qml). Noctalia used to render a runtime
  # theme file here; with the quickshell rewrite that templating is gone, so
  # a static bundled theme is the whole story.
  flake.modules.homeManager.homeManager = {
    xdg.configFile."ghostty/config".text = ''
      theme = GruvboxDark

      # No "Close Window? All terminal sessions will be terminated" dialog —
      # closing a surface just closes it, even with a shell/TUI still running.
      confirm-close-surface = false
    '';
  };
}
