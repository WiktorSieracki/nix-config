{
  flake.modules = {
    nixos.java = {pkgs, ...}: {
      environment.sessionVariables = {
        JAVA_HOME = "${pkgs.zulu25}";
      };

      programs.java = {
        enable = true;
        package = pkgs.zulu25;
      };

      environment.systemPackages = with pkgs; [
        gradle_9
      ];
    };

    # homeManager.java = {pkgs, ...}: {
    #   programs.fish.enable = true;
    #   programs.fish.shellInit = ''
    #     set -gx JAVA_HOME ${pkgs.zulu25}
    #   '';

    #   programs.java = {
    #     enable = true;
    #     package = pkgs.zulu25;
    #   };

    #   home.packages = with pkgs; [
    #     gradle_9
    #   ];
    # };
  };
}
