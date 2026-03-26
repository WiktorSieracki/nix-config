{
  flake.modules.homeManager.java = {pkgs, ...}: {
    home.packages = with pkgs; [
      zulu25
      gradle_9
    ];

    home.sessionVariables = {
      JAVA_HOME = "${pkgs.zulu25}";
    };
  };
}
