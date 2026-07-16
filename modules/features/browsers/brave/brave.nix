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
    requires = ["desktop"];
    kind = "gui";
  };

  flake.featureTests.brave = {
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("home-manager-tester.service")
      machine.succeed("su - tester -c 'command -v brave'")
    '';
  };
}
