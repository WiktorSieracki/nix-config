{
  # Wiktor's personal machine aliases (`ssh laptop`, `ssh desktop`), split out
  # of the generic `ssh` feature because they log in as a *concrete* account —
  # exactly what a shared user feature must not hardcode (ADR 0004). Enable
  # only on the accounts that should reach these machines as wiktor.
  #
  # One block per machine: the short name is the `Host` alias, `HostName`
  # points at the real Tailscale MagicDNS name (the machine's hostname,
  # lowercased). A bare `Host laptop laptopnixos` pattern without `HostName`
  # only *matches* settings — it never resolved, so `ssh laptop` used to fail
  # with "Could not resolve hostname". The long names still work raw via
  # MagicDNS, just without this block's settings.
  flake.modules.homeManager.ssh-personal-hosts = {
    programs.ssh.settings = {
      "laptop" = {
        HostName = "laptopnixos";
        User = "wiktor";
        IdentityFile = "~/.ssh/id_ed25519";
        ServerAliveInterval = "60";
        ServerAliveCountMax = "3";
        ConnectTimeout = "30";
      };
      "desktop" = {
        HostName = "desktopnixos";
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

  # feature test: the aliases only work if the block carries a HostName that
  # translates the short name — a bare Host pattern regresses to an
  # unresolvable alias, so assert the translation, not just the block.
  flake.featureTests.ssh-personal-hosts = {
    testScript = ''
      machine.succeed("su - tester -c 'grep -iq hostname.laptopnixos ~/.ssh/config'")
      machine.succeed("su - tester -c 'grep -iq hostname.desktopnixos ~/.ssh/config'")
    '';
  };
}
