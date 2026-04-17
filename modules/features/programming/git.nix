{
  flake.modules = {
    homeManager.git = {
      programs.git = {
        enable = true;
        signing.format = null;

        settings.user = {
          email = "w.sieracki.643@studms.ug.edu.pl";
          name = "Wiktor Sieracki";
        };
      };
    };

    nixos.git = {pkgs, ...}: {
      environment.systemPackages = with pkgs; [
        gh
      ];
    };
  };
}
