{
  flake.modules.nixos.java = {pkgs, ...}: {
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

  # Pure system feature: zulu25 JDK + gradle on PATH, no user config.
  flake.featureMeta.java = {
    requires = [];
    kind = "cli";
  };

  # Próba: java and gradle are on PATH and respond to version flags.
  flake.featureTests.java = {
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("java -version")
      machine.succeed("gradle --version")
    '';
  };
}
