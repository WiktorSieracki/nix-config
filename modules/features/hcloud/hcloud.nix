{
  # Hetzner Cloud CLI — provisions and inspects the `vpsNixos` server. The
  # API token is per-account state: `hcloud context create <project>` writes
  # it to ~/.config/hcloud/cli.toml (mode 600), so nothing secret lives here.
  # The package ships its own fish completions (vendor_completions.d).
  flake.modules.nixos.hcloud = {pkgs, ...}: {
    environment.systemPackages = [pkgs.hcloud];
  };

  flake.featureMeta.hcloud = {
    requires = [];
    kind = "cli";
    provides.systemBins = ["hcloud"];
  };

  # feature test: `provides` covers PATH; without a token every API call
  # fails, so a version call is as far as a VM goes.
  flake.featureTests.hcloud = {
    testScript = ''
      machine.succeed("hcloud version")
    '';
  };
}
