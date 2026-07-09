{
  # Ships the default wallpaper into the user's own home — each account
  # listing this feature gets its own copy, so a fresh account (e.g. `work`)
  # doesn't greet you with a black screen.
  flake.modules.homeManager.wallpapers = {
    home.file = {
      "Pictures/Wallpapers/wallhaven_p92g1m.jpg".source = ./wallhaven_p92g1m.jpg;
    };
  };

  flake.featureMeta.wallpapers = {
    requires = [];
    kind = "config";
  };

  flake.probaTests.wallpapers = {
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("home-manager-proba.service")
      machine.succeed("test -f /home/proba/Pictures/Wallpapers/wallhaven_p92g1m.jpg")
    '';
  };
}
