{
  flake.modules.nixos.switchboard = {pkgs, ...}: {
    environment.systemPackages = [
      # Single-file Textual app kept in this feature's folder; the wrapper pins
      # a python3 with textual so the tool is self-contained on PATH.
      (pkgs.writeShellScriptBin "switchboard" ''
        exec ${pkgs.python3.withPackages (ps: [ps.textual])}/bin/python3 ${./switchboard.py} "$@"
      '')
    ];
  };

  # Switchboard drives `nix eval`/`nix build` itself (ambient in core), but its
  # finale shells out to `nh os test/switch` — provided by the `nix` feature.
  flake.featureMeta.switchboard = {
    requires = ["nix"];
    kind = "cli";
  };

  # Próba (kind cli): the binary is on PATH and handles --version/--help
  # headless (no TTY) with exit 0 — the TUI itself needs a real terminal.
  # The `requires` closure pulls in `nix`, whose nixpkgs.config.allowUnfree
  # collides with nixosTest's read-only nixpkgs — force-override it, same
  # stub as the nix feature's own Próba.
  flake.probaTests.switchboard = {
    extraNixosModules = [
      ({lib, ...}: {nixpkgs.config = lib.mkForce {allowUnfree = true;};})
    ];
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("command -v switchboard")
      machine.succeed("switchboard --version")
      machine.succeed("switchboard --help")
    '';
  };
}
