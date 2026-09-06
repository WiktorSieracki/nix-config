{
  flake.modules = {
    nixos.fish = {pkgs, ...}: {
      programs.fish.enable = true;

      programs.nix-index = {
        enable = true;
        package = pkgs.nix-index;
        enableFishIntegration = true;
      };

      # NOTE: the login shell is NOT set here. Which account uses fish as its
      # shell is identity data — it lives in flake.meta.users.<login>.shell and
      # the host loader (mkHostUser) applies it. This module only provides fish.
    };

    homeManager.fish = {
      pkgs,
      lib,
      ...
    }: {
      # fish-ssh-agent (below) starts the agent by redirecting into $SSH_ENV,
      # which defaults to ~/.ssh/environment, then chmod-ing and sourcing it.
      # On a home that has never had an ssh key -- the installer ISO, a fresh
      # install, any new user -- ~/.ssh does not exist, so all three steps fail
      # and every single login opens with four lines of error. Create the
      # directory so the plugin has somewhere to write.
      home.activation.ensureSshDir = lib.hm.dag.entryAfter ["writeBoundary"] ''
        run mkdir -p -m 700 "$HOME/.ssh"
      '';

      programs = {
        direnv = {
          enable = true;
          enableFishIntegration = true;
          nix-direnv.enable = true;
        };
      };

      programs.fish = {
        enable = true;

        shellAliases = {
          npx = "pnpx";
          npm = "pnpm";
          nnpm = "npm";
          nnpx = "npx";
        };

        plugins = [
          {
            name = "z";
            src = pkgs.fishPlugins.z.src;
          }
          {
            name = "fish-ssh-agent";
            src = pkgs.fetchFromGitHub {
              owner = "danhper";
              repo = "fish-ssh-agent";
              rev = "f10d95775352931796fd17f54e6bf2f910163d1b";
              sha256 = "cFroQ7PSBZ5BhXzZEKTKHnEAuEu8W9rFrGZAb8vTgIE=";
            };
          }
        ];
      };
    };
  };

  # Fish shell: system-level programs.fish.enable + nix-index integration,
  # HM direnv + plugins. Login-shell assignment lives in flake.meta.users.
  flake.featureMeta.fish = {
    requires = [];
    kind = "config";
    provides = {
      systemBins = ["fish"];
      userBins = ["direnv"];
    };
  };

  # feature test: shell *assignment* is the loader's job — asserted by the
  # host-users mechanism check, not here. `provides` covers the rest.
  flake.featureTests.fish = {};
}
