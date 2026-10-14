{self, ...}: {
  perSystem = {pkgs, ...}: {
    # `nix fmt` formats the whole tree with the repo's formatter.
    formatter = pkgs.alejandra;

    # `nix flake check` / CI gate: fails if any file under the flake source
    # needs formatting. Runs on `self` (the git-tracked tree), so it needs no
    # network and no IFD. Not a feature test, so feature-coverage ignores it
    # (it audits `flake.featureMeta`/`featureTests`, not `checks`).
    checks.formatting =
      pkgs.runCommand "formatting-check" {
        nativeBuildInputs = [pkgs.alejandra];
      } ''
        alejandra --check ${self}
        touch $out
      '';
  };
}
