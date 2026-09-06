{
  description = "Nix configuration for my machines";

  # Honored by CI (accept-flake-config = true in the workflows) and by any
  # trusted-user nix invocation; NixOS hosts get the same list via
  # nix.settings in the `nix` and `cachix` features.
  nixConfig = {
    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://cache.numtide.com"
      "https://wiktor-nixos.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      "wiktor-nixos.cachix.org-1:3DOZHbBhM0h+YZFUZ1zZikBSLC7cTbZglgQEhF7Gi2M="
    ];
  };

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

    # Claude Code skill sources, consumed as raw file trees (flake = false) by
    # the `claude-skills` feature, which links each skill folder into
    # ~/.claude/skills/. Bump with `nix flake update mattpocock-skills`.
    mattpocock-skills = {
      url = "github:mattpocock/skills";
      flake = false;
    };

    vercel-skills = {
      url = "github:vercel-labs/skills";
      flake = false;
    };
  };

  outputs = inputs: inputs.flake-parts.lib.mkFlake {inherit inputs;} (inputs.import-tree ./modules);
}
