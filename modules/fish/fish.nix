{ inputs, pkgs, ... }:

let
  java = import ../java.nix { inherit inputs pkgs; };
in
{
  programs.bash = {
    enable = true;
    initExtra = ''
      if [[ $(${pkgs.procps}/bin/ps --no-header --pid=$PPID --format=comm) != "fish" && -z ''${BASH_EXECUTION_STRING} ]]
      then
        shopt -q login_shell && LOGIN_OPTION='--login' || LOGIN_OPTION=""
        exec ${pkgs.fish}/bin/fish $LOGIN_OPTION
      fi
    '';
  };

  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      # Enable Vi mode
      fish_vi_key_bindings
    '';
    functions = {
      # to change fish prompt using fish_config
      # you need to delete those two functions in fish/functions folder
      # then type fish_config and change some prompts
      # fish_prompt = (builtins.readFile ./fish_prompt.fish);
      # fish_right_prompt = (builtins.readFile ./fish_right_prompt.fish);
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
    shellInit = ''
      fish_config prompt choose disco
      ssh-add ~/.ssh/gitlab > /dev/null 2>&1
      ssh-add ~/.ssh/github > /dev/null 2>&1
      set -x JAVA_HOME ${java.home.sessionVariables.JAVA_HOME}
    '';
  };
}
