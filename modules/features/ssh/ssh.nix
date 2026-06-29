{
  flake.modules.homeManager.ssh = {
    # Migrated from the deprecated `programs.ssh.matchBlocks`/`extraOptions` to
    # `programs.ssh.settings` (home-manager): the attribute name is the `Host`
    # pattern and option keys are upstream OpenSSH directive names. Folding the
    # short alias into the same pattern (`laptop laptopnixos`) so `ssh laptop`
    # actually resolves — the old `host = "..."` override silently dropped the
    # alias and emitted a duplicate `Host laptopnixos` block instead.
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;

      settings = {
        "laptop laptopnixos" = {
          User = "wiktor";
          IdentityFile = "~/.ssh/id_ed25519";
          ServerAliveInterval = "60";
          ServerAliveCountMax = "3";
          ConnectTimeout = "30";
        };
        "desktop desktopnixos" = {
          User = "wiktor";
          IdentityFile = "~/.ssh/id_ed25519";
          ServerAliveInterval = "60";
          ServerAliveCountMax = "3";
          ConnectTimeout = "30";
        };
        "github.com" = {
          User = "git";
          IdentityFile = "~/.ssh/id_ed25519";
        };
        "gitlab.com" = {
          User = "git";
          IdentityFile = "~/.ssh/id_ed25519";
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
