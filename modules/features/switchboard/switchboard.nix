{
  flake.modules.nixos.switchboard = {pkgs, ...}: {
    environment.systemPackages = [
      # Go/bubbletea TUI whose sources live in this feature's folder
      # (self-sufficiency): buildGoModule vendors the deps from go.sum and
      # also runs `go test ./...` in its checkPhase, so the domain-logic unit
      # tests gate every build.
      (pkgs.buildGoModule {
        pname = "switchboard";
        version = "0.2.0";
        src = ./.;
        vendorHash = "sha256-4rK69s1uTFBV20endymLw6JEUfrh51bznZEgbujUQls=";
        meta.mainProgram = "switchboard";
      })
    ];
  };

  # Switchboard drives `nix eval`/`nix build` itself (ambient in core), but its
  # finale shells out to `nh os test/switch` — provided by the `nix` feature.
  flake.featureMeta.switchboard = {
    requires = ["nix"];
    kind = "cli";
    provides.systemBins = ["switchboard"];
  };

  # feature test (kind cli): the binary is on PATH and handles --version/--help
  # headless (no TTY) with exit 0 — the TUI itself needs a real terminal.
  # The `requires` closure pulls in `nix`, whose nixpkgs.config.allowUnfree
  # collides with nixosTest's read-only nixpkgs — force-override it, same
  # stub as the nix feature's own feature test.
  flake.featureTests.switchboard = {
    extraNixosModules = [
      ({lib, ...}: {nixpkgs.config = lib.mkForce {allowUnfree = true;};})
    ];
    testScript = ''
      machine.succeed("switchboard --version")
      machine.succeed("switchboard --help")
    '';
  };
}
