{
  flake.modules = {
    nixos.fish = {pkgs, ...}: {
      programs.fish.enable = true;

      programs.nix-index = {
        enable = true;
        package = pkgs.nix-index;
        enableFishIntegration = true;
      };

      users.users.wiktor = {
        shell = pkgs.fish;
      };
    };

    homeManager.fish = {pkgs, ...}: {
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
  # HM direnv + plugins. Sets wiktor's login shell to fish, so requires `wiktor`.
  flake.featureMeta.fish = {
    requires = ["wiktor"];
    kind = "config";
  };

  # Próba: fish binary on PATH and wiktor's shell is fish.
  flake.probaTests.fish = {
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("home-manager-wiktor.service")
      machine.succeed("command -v fish")
      machine.succeed("getent passwd wiktor | cut -d: -f7 | grep -q fish")
    '';
  };
}
