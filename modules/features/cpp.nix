{
  flake.modules.homeManager.cpp = {pkgs, ...}: {
    home.packages = with pkgs; [
      cmake
      clang
      clang-tools
      just
    ];
  };
}
