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
  };

  # Próba: home-manager activates and the C++ toolchain CLIs are on wiktor's PATH.
  flake.featureTests.cpp = {
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("home-manager-tester.service")
      machine.succeed("su - tester -c 'cmake --version'")
      machine.succeed("su - tester -c 'clang --version'")
      machine.succeed("su - tester -c 'just --version'")
      machine.succeed("su - tester -c 'make --version'")
    '';
  };
}
