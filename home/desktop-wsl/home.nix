{...}: {
  imports = [
    ../shared.nix
  ];

  # WSL-specific packages
  home.packages = [
  ];

  # WSL-specific environment variables
  home.sessionVariables = {
    # WSL-specific PATH additions or other env vars
    DISPLAY = ":0"; # For X11 forwarding if needed
  };

  # WSL-specific configuration
  targets.genericLinux.enable = true;

  programs.fish.interactiveShellInit = ''
    # Enable Vi mode
    fish_default_key_bindings
  '';
}
