{ pkgs, ... }:

{
  home.packages = [
    (pkgs.python312.withPackages (python-pkgs: [
      python-pkgs.numpy
      python-pkgs.pyautogui
      python-pkgs.pandas
      python-pkgs.matplotlib
      python-pkgs.scipy
      python-pkgs.opencv4
      python-pkgs.scikit-image
      python-pkgs.pygame
      python-pkgs.requests
    ]))
    pkgs.uv
    pkgs.ruff
  ];
}
