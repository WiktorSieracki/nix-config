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
    requires = ["wiktor"];
    kind = "cli";
  };

  # Próba: home-manager activates and the C++ toolchain CLIs are on wiktor's PATH.
  flake.probaTests.cpp = {
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("home-manager-wiktor.service")
      machine.succeed("su - wiktor -c 'cmake --version'")
      machine.succeed("su - wiktor -c 'clang --version'")
      machine.succeed("su - wiktor -c 'just --version'")
      machine.succeed("su - wiktor -c 'make --version'")
    '';
  };
}
