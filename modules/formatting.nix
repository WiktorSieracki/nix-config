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

    # Lint gate next to the formatter: deadnix fails on unused bindings and
    # lambda arguments, statix on anti-patterns. statix reads statix.toml
    # from the tree root; `repeated_keys` is disabled there because the
    # dendritic layout repeats `flake.modules.*` / `flake.featureMeta.*` in
    # every feature file on purpose. Fix locally with `statix fix` /
    # `deadnix --edit`.
    checks.lint =
      pkgs.runCommand "lint-check" {
        nativeBuildInputs = [pkgs.deadnix pkgs.statix];
      } ''
        cd ${self}
        deadnix --fail .
        statix check .
        touch $out
      '';
  };
}
