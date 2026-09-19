{
  description = "Nix configuration for my machines";

  # Deliberately no `nixConfig` here. A flake's nixConfig is only honored when
  # the caller passes `--accept-flake-config` (or has the exact value string
  # already saved in ~/.local/share/nix/trusted-settings.json) -- being a
  # trusted user is not enough, because non-interactively Nix has nobody to ask.
  # So every local `nh os switch` printed two "ignoring untrusted flake
  # configuration setting" warnings for a list the host already had anyway.
  #
  # The substituters live in exactly the places that can actually honor them:
  #   - installed hosts + the ISO: nix.settings in the `nix` and `cachix`
  #     features (the ISO enables `nix`, so its image carries all four caches --
  #     `nix eval .#nixosConfigurations.iso.config.nix.settings.substituters`).
  #   - CI: extra_nix_config in .github/workflows/*.yaml.

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default-linux";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    import-tree.url = "github:vic/import-tree";

    wrapper-modules = {
      url = "github:BirdeeHub/nix-wrapper-modules";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix4vscode = {
      url = "github:nix-community/nix4vscode";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # llm-agents deliberately does NOT follow our nixpkgs: upstream pushes CI
    # builds to its binary cache (cache.numtide.com) built against THEIR locked
    # nixpkgs. A `follows` would change every hash and force local Rust/Go
    # compiles on each nixpkgs bump. Costs a second nixpkgs eval; buys binary
    # downloads.
    llm-agents.url = "github:numtide/llm-agents.nix";

    # Agent skill source, consumed as a raw file tree (flake = false) by the
    # `mattpocock-skills` feature, which links each skill folder into every
    # agent's skill root (~/.claude, ~/.agents, ~/.gemini).
    # Bump with `nix flake update mattpocock-skills`.
    mattpocock-skills = {
      url = "github:mattpocock/skills";
      flake = false;
    };

    # Cursor's plugin monorepo; only `pstack/` is consumed, by the `pstack`
    # feature. Bump with `nix flake update cursor-plugins`.
    cursor-plugins = {
      url = "github:cursor/plugins";
      flake = false;
    };
  };

  outputs = inputs: inputs.flake-parts.lib.mkFlake {inherit inputs;} (inputs.import-tree ./modules);
}
