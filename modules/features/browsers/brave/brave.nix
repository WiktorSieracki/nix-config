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
    provides.userBins = ["brave"];
  };

  # feature test: fully covered by `provides` — no extra script needed.
  flake.featureTests.brave = {};
}
