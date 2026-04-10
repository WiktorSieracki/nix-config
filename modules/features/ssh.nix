{
  flake.modules.homeManager.ssh = {
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;

      matchBlocks = {
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
