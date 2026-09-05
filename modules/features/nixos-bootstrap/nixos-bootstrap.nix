{config, ...}: let
  meta = config.flake.meta;
in {
  # The installer image's one command: install a host, put the SOPS key where
  # first-boot activation will look for it, and leave the account's checkout in
  # place. See bootstrap.sh for what each step is for.
  #
  # A system feature, not a user one: it runs as root on the live image against
  # a target under /mnt, and the account it sets up does not exist yet.
  flake.modules.nixos.nixos-bootstrap = {pkgs, ...}: {
    environment.systemPackages = [
      (pkgs.writeShellApplication {
        name = "nixos-bootstrap";
        runtimeInputs = with pkgs; [
          git
          jq
          openssh # ssh-keygen, for verifying the key against its public half
          util-linux # mountpoint
        ];
        text =
          builtins.replaceStrings
          ["@httpsUrl@" "@sshUrl@" "@flakeRef@" "@bwItem@" "@primaryUser@"]
          [
            meta.repo.https
            meta.repo.ssh
            meta.repo.flake
            meta.bitwarden.sshKeyItem
            meta.primaryUser
          ]
          (builtins.readFile ./bootstrap.sh);
      })
    ];
  };

  flake.featureMeta.nixos-bootstrap = {
    # `nixos-install` and `nix` come from the installer profile and the `nix`
    # feature respectively; the Bitwarden CLI is fetched at run time on purpose
    # (see the `bitwarden` feature for why it is not on the image).
    requires = ["nix"];
    kind = "cli";
    provides.systemBins = ["nixos-bootstrap"];
  };

  # feature test: a real run needs a mounted target, a Bitwarden account and the
  # network, none of which a sandboxed VM has. What *is* worth pinning down is
  # that the script refuses to do damage when its preconditions are unmet —
  # a bootstrap that starts installing onto an unmounted /mnt is worse than one
  # that does nothing.
  flake.featureTests.nixos-bootstrap = {
    # Inherited from `requires = ["nix"]`: that feature sets
    # `nixpkgs.config.allowUnfree`, and in a nixosTest `nixpkgs.config` is
    # read-only (pkgs are pre-evaluated and handed in), so it has to be forced.
    # Same workaround as the `nix` feature's own test.
    extraNixosModules = [
      ({lib, ...}: {nixpkgs.config = lib.mkForce {allowUnfree = true;};})
    ];
    testScript = ''
      # --help must work with no privileges and no target.
      machine.succeed("nixos-bootstrap --help")

      # No host named -> refuses.
      machine.fail("nixos-bootstrap")

      # /mnt is not a mountpoint in the test VM, so a named host must still
      # refuse rather than start installing.
      out = machine.fail("nixos-bootstrap desktopNixos 2>&1")
      assert "not a mountpoint" in out, f"expected a mountpoint complaint, got: {out}"

      # An unknown option is an error, not something silently treated as a host.
      machine.fail("nixos-bootstrap --nonsense")
    '';
  };
}
