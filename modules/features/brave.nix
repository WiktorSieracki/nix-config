{
  flake.modules.homeManager.brave = {pkgs, ...}: {
    programs.brave = {
      enable = true;
      package = pkgs.brave;
      extensions = [
        "pbanhockgagggenencehbnadejlgchfc" # simplify-jobs
      ];
    };
  };
}
