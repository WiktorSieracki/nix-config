{
  flake.modules.homeManager.cpp = {pkgs, ...}: {
    home.packages = with pkgs; [
      cmake
      clang
      clang-tools
      just
      gnumake
    ];
  };

  # HM-only feature: cmake, clang, clang-tools, just, and make installed for wiktor.
  flake.featureMeta.cpp = {
    requires = [];
    kind = "cli";
    provides.userBins = ["cmake" "clang" "just" "make"];
  };

  # feature test: `provides` covers PATH; the version calls are the runtime smoke.
  flake.featureTests.cpp = {
    testScript = ''
      machine.succeed("su - tester -c 'cmake --version'")
      machine.succeed("su - tester -c 'clang --version'")
      machine.succeed("su - tester -c 'just --version'")
      machine.succeed("su - tester -c 'make --version'")
    '';
  };
}
