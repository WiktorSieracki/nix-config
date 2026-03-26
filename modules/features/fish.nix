{
  flake.modules = {

    nixos.fish = {pkgs, ...}: {
      programs.fish.enable = true;

      users.users.wiktor = {
        shell = pkgs.fish;
      };
    };

    homeManager.fish = {pkgs, ...}: {

  programs.fish = {
    enable = true;

    #TODO: fix this, it breaks the shell
    # interactiveShellInit = '';
    #   fish_config prompt choose disco
    # '';

    shellAliases = {
      npx = "pnpx";
      npm = "pnpm";
      nnpm = "npm";
      nnpx = "npx";
    };
    functions = {
      nix-fish = ''
        nix shell $argv --command fish
      '';
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
      # set -x JAVA_HOME ${java.home.sessionVariables.JAVA_HOME}
    # shellInit = ''
    #   fish_config prompt choose disco
    #   ssh-add ~/.ssh/id_ed25519 > /dev/null 2>&1
    # '';
  };
  };
  };
}