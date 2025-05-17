{ pkgs, ... }:
{
  home.packages = [
    pkgs.typst
    pkgs.typstfmt
  ];
}
