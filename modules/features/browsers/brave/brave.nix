{
  flake.modules.homeManager.brave = {pkgs, ...}: {
    programs.brave = {
      enable = true;
      package = pkgs.brave;
      extensions = [
        "pbanhockgagggenencehbnadejlgchfc" # simplify-jobs
        "nngceckbapebfimnlniiiahkandclblb" # bitwarden
        "hfjbmagddngcpeloejdejnfgbamkjaeg" # vimium c
        "eimadpbcbfnmbkopoojfekhnkhdbieeh" # dark reader
      ];
    };
  };

  flake.featureMeta.brave = {
    requires = ["wiktor"];
    kind = "gui";
  };

  flake.probaTests.brave = {
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("home-manager-wiktor.service")
      machine.succeed("su - wiktor -c 'command -v brave'")
    '';
  };
}
