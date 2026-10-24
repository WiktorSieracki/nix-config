{
  flake.modules.nixos.bitwarden = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      bitwarden-desktop
      bitwarden-cli
    ];
  };

  flake.featureMeta.bitwarden = {
    requires = ["desktop"];
    kind = "gui";
    # Desktop app ships as `bitwarden`; the CLI (`bitwarden-cli`) as `bw`.
    provides.systemBins = ["bitwarden" "bw"];
  };

  # feature test: fully covered by `provides` — no extra script needed.
  flake.featureTests.bitwarden = {};
}
