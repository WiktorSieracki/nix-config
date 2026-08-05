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
    provides.systemBins = ["java" "gradle"];
  };

  # feature test: `provides` covers PATH; the version calls are the smoke that a
  # toolchain actually runs (a broken JDK is on PATH but won't start).
  flake.featureTests.java = {
    testScript = ''
      machine.succeed("java -version")
      machine.succeed("gradle --version")
    '';
  };
}
