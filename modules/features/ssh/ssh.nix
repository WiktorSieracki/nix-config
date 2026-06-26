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

  flake.featureMeta.ssh = {
    requires = ["wiktor"];
    kind = "config";
  };

  flake.probaTests.ssh = {
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("home-manager-wiktor.service")
      machine.succeed("su - wiktor -c 'test -f ~/.ssh/config'")
      machine.succeed("su - wiktor -c 'ssh -V'")
    '';
  };
}
