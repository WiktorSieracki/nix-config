{
  flake.modules.nixos.nix = {pkgs, ...}: {
    nixpkgs.config.allowUnfree = true;
    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
    # Periodic store deduplication (hardlinks identical files; default 03:45
    # daily). Deliberately a timer, not auto-optimise-store = true — the
    # per-build variant slows builds and has a history of hardlink races.
    nix.optimise.automatic = true;
    nix.settings.substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
      # upstream CI caches for the llm-agents and agent-of-empires flake
      # inputs — only hit because those inputs don't `follows` our nixpkgs
      "https://cache.numtide.com"
      "https://agent-of-empires.cachix.org"
    ];
    nix.settings.trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      "agent-of-empires.cachix.org-1:Z+VwTlT8GT7giWN9HhJ+Am0DPGfbFVlafcQioBqJ6wY="
    ];

    environment.systemPackages = with pkgs; [
      alejandra
      nixd
      nix-search-cli
      nixfmt
      nh
      comma
      manix
    ];

    environment.sessionVariables = {
      NH_FLAKE = "/home/wiktor/.config/nix-config";
      FLAKE = "/home/wiktor/.config/nix-config";
      # Lets ad-hoc `nix shell/run nixpkgs#pkg --impure` and legacy
      # nix-shell/nix-env (impure by default already) pick up unfree
      # packages too; system builds already get allowUnfree via the
      # config above.
      NIXPKGS_ALLOW_UNFREE = "1";
    };
  };

  # Nix daemon config + dev toolchain (alejandra, nixd, nh, manix, comma…).
  # kind `config`: the feature mainly sets nix.settings; the installed CLIs
  # are a bonus. No user-level deps.
  flake.featureMeta.nix = {
    requires = [];
    kind = "config";
  };

  # Próba: confirm key dev tools installed by this feature are on PATH.
  # nixpkgs.config in nixosTest is read-only (pkgs are pre-evaluated and
  # passed in), so we force-override it in extraNixosModules to avoid the
  # "defined multiple times" error from the allowUnfree setting in the module.
  flake.featureTests.nix = {
    extraNixosModules = [
      ({lib, ...}: {nixpkgs.config = lib.mkForce {allowUnfree = true;};})
    ];
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("alejandra --version")
      machine.succeed("nh --version")
      machine.wait_for_unit("nix-optimise.timer")
    '';
  };
}
