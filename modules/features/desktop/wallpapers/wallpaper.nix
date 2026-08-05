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
    provides.userFiles = ["~/Pictures/Wallpapers/wallhaven_p92g1m.jpg"];
  };

  # feature test: fully covered by `provides` — no extra script needed.
  flake.featureTests.wallpapers = {};
}
