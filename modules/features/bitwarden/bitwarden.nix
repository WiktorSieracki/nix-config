{
  # The Bitwarden CLI, as a user feature: `bw` keeps its session and config in
  # `~/.config/Bitwarden CLI`, so it belongs to an account, not to the machine.
  #
  # Deliberately NOT enabled on the `iso` host. Its closure is ~437 MiB, and the
  # installer image has ~238 MiB of headroom under GitHub's 2 GiB release limit
  # — baking it in would put the single-file release back at risk. The installer
  # fetches it at run time instead (see the `nixos-bootstrap` feature), which
  # costs nothing extra: bootstrapping already requires the network.
  flake.modules.homeManager.bitwarden = {pkgs, ...}: {
    home.packages = [pkgs.bitwarden-cli];
  };

  flake.featureMeta.bitwarden = {
    requires = [];
    kind = "cli";
    provides.userBins = ["bw"];
  };

  # feature test: a plain CLI on PATH — `provides` says all there is to say.
  # Anything further needs a real vault and network.
  flake.featureTests.bitwarden = {};
}
