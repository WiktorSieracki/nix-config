{
  flake.modules.homeManager.ssh = {
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;

      matchBlocks = {
        "laptop" = {
          host = "laptopnixos";
          user = "wiktor";
          identityFile = "~/.ssh/id_ed25519";
        };
        "laptopnixos" = {
          user = "wiktor";
          identityFile = "~/.ssh/id_ed25519";
          extraOptions = {
            ServerAliveInterval = "60";
            ServerAliveCountMax = "3";
            ConnectTimeout = "30";
          };
        };
        "desktop" = {
          host = "desktopnixos";
          user = "wiktor";
          identityFile = "~/.ssh/id_ed25519";
        };
        "desktopnixos" = {
          user = "wiktor";
          identityFile = "~/.ssh/id_ed25519";
          extraOptions = {
            ServerAliveInterval = "60";
            ServerAliveCountMax = "3";
            ConnectTimeout = "30";
          };
        };
        "github.com" = {
          user = "git";
          identityFile = "~/.ssh/id_ed25519";
        };
        "gitlab.com" = {
          user = "git";
          identityFile = "~/.ssh/id_ed25519";
        };
      };
    };

    services.ssh-agent.enable = true;
  };
}
