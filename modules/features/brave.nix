{
  flake.modules.homeManager.brave =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.brave ];

      programs.chromium = {
        enable = true;
        extensions = [
          "mclhabbadhkandmgbifoejaadhmeonon"
          "nngceckbapebfimnlniiiahkandclblb"
        ];
      };
    };
}
