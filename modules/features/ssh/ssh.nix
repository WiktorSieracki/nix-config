{
  # Generic, user-agnostic ssh client config (ADR 0004). Personal host
  # aliases that log in as a concrete account live in `ssh-personal-hosts`.
  # `~/.ssh/id_ed25519` is a per-account path — each user brings their own
  # key (e.g. `work` has a separate key for its own GitHub account).
  flake.modules.homeManager.ssh = {
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;

      settings = {
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
    requires = [];
    kind = "config";
    provides = {
      userBins = ["ssh"];
      userFiles = ["~/.ssh/config"];
    };
  };

  # feature test: fully covered by `provides` — no extra script needed.
  flake.featureTests.ssh = {};
}
