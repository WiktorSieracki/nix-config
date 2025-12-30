{pkgs, ...}: {
  home.packages = [
    pkgs.roboto
    pkgs.source-sans-pro
    pkgs.typstPackages.fontawesome
  ];
}
