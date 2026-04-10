{ inputs, ... }:

let
  pkgs = import inputs.nixpkgs {
    system = "x86_64-linux";
    config.allowUnfree = true;
  };
  handy = pkgs.appimageTools.wrapType2 {
    pname = "handy";
    version = "0.7.6";
    src = pkgs.fetchurl {
      url = "https://github.com/cjpais/Handy/releases/download/v0.7.6/Handy_0.7.6_amd64.AppImage";
      sha256 = "sha256-UZNt3lfKo6dBRWK1YD03HmcZsx/Zu2J3eD5VdTw+poU=";
    };
    extraRuntimeDependencies = [ ];
  };
in
{
  flake.modules.homeManager.handy = {
    home.packages = [ handy ];
  };
}
