{
  # Wiktor's personal machine aliases (`ssh laptop`, `ssh desktop`), split out
  # of the generic `ssh` feature because they log in as a *concrete* account —
  # exactly what a shared user feature must not hardcode (ADR 0004). Enable
  # only on the accounts that should reach these machines as wiktor.
  #
  # Migrated from the deprecated `programs.ssh.matchBlocks`/`extraOptions` to
  # `programs.ssh.settings` (home-manager): the attribute name is the `Host`
  # pattern. Folding the short alias into the same pattern (`laptop
  # laptopnixos`) so `ssh laptop` actually resolves.
  flake.modules.homeManager.ssh-personal-hosts = {
    programs.ssh.settings = {
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
    };
  };

  # Merges into programs.ssh.settings, so the client config (programs.ssh
  # .enable, enableDefaultConfig=false) must come from `ssh`.
  flake.featureMeta.ssh-personal-hosts = {
    requires = ["ssh"];
    kind = "config";
    provides.userFiles = ["~/.ssh/config"];
  };

  # feature test: this feature's content is host *aliases*, so the assertion has
  # to look inside the file `provides` proves exists.
  flake.featureTests.ssh-personal-hosts = {
    testScript = ''
      machine.succeed("su - tester -c 'grep -q laptopnixos ~/.ssh/config'")
    '';
  };
}
