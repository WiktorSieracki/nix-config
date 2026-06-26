{
  flake.modules.nixos.nix = {pkgs, ...}: {
    nixpkgs.config.allowUnfree = true;
    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
    nix.settings.substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
    ];
    nix.settings.trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
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
  flake.probaTests.nix = {
    extraNixosModules = [
      ({lib, ...}: {nixpkgs.config = lib.mkForce {allowUnfree = true;};})
    ];
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("alejandra --version")
      machine.succeed("nh --version")
    '';
  };
}
