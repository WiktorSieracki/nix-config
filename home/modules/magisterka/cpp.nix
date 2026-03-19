{pkgs, ...}: {
  home.packages = with pkgs; [
    cmake
    clang
    clang-tools
    just
  ];
}
