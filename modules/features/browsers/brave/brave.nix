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
    requires = [];
    kind = "gui";
  };

  flake.probaTests.brave = {
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("home-manager-proba.service")
      machine.succeed("su - proba -c 'command -v brave'")
    '';
  };
}
