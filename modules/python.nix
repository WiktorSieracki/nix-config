{ pkgs, ... }:

{
  home.packages = [
    (pkgs.python3.withPackages (python-pkgs: [
      python-pkgs.numpy
      python-pkgs.pandas
      python-pkgs.matplotlib
      python-pkgs.scipy
      python-pkgs.opencv4
      python-pkgs.scikit-image
      python-pkgs.pygame
    ]))
  ];
}
