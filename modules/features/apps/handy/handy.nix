{inputs, ...}: let
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
    extraRuntimeDependencies = [];
  };
in {
  flake.niriBinds.handy = {...}: {
    "Mod+V".spawn-sh = "pgrep -x handy || handy --start-hidden --no-tray; pkill -USR2 -x handy";
  };

  flake.modules.homeManager.handy = {
    home.packages = [
      handy
      pkgs.wtype
    ];
  };

  flake.featureMeta.handy = {
    requires = [];
    kind = "gui";
  };

  # Próba: handy is an AppImage wrapped via appimageTools; binary is `handy`.
  # Asserted as wiktor since it lives in the HM profile.
  flake.probaTests.handy = {
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("home-manager-proba.service")
      machine.succeed("su - proba -c 'command -v handy'")
    '';
  };
}
