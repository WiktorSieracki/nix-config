{inputs, ...}: {
  flake.modules = {
    homeManager.git = {config, ...}: {
      imports = [
        inputs.sops-nix.homeManagerModules.sops
      ];

      sops.secrets.studentEmail = {};

      sops.templates."git-user-email".content = ''
        [user]
          email = ${config.sops.placeholder.studentEmail}
      '';

      programs.git = {
        enable = true;
        signing.format = null;
        includes = [
          {
            path = config.sops.templates."git-user-email".path;
          }
        ];

        settings.user = {
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
