{
  flake.modules.nixos.bruno = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      bruno
      bruno-cli
    ];
  };

  flake.featureMeta.bruno = {
    requires = ["desktop"];
    kind = "gui";
    provides.systemBins = ["bruno"];
  };

  # feature test: fully covered by `provides` — no extra script needed.
  flake.featureTests.bruno = {};
}
