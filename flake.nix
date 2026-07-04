{
  description = "Nix configuration for my machines";

  # Honored by CI (accept-flake-config = true in the workflows) and by any
  # trusted-user nix invocation; NixOS hosts get the same list via
  # nix.settings in the `nix` and `cachix` features.
  nixConfig = {
    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://cache.numtide.com"
      "https://agent-of-empires.cachix.org"
      "https://wiktor-nixos.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      "agent-of-empires.cachix.org-1:Z+VwTlT8GT7giWN9HhJ+Am0DPGfbFVlafcQioBqJ6wY="
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

    # llm-agents and agent-of-empires deliberately do NOT follow our nixpkgs:
    # both upstreams push CI builds to their binary caches (cache.numtide.com,
    # agent-of-empires.cachix.org) built against THEIR locked nixpkgs. A
    # `follows` would change every hash and force local Rust/Go compiles on
    # each nixpkgs bump. Costs a second nixpkgs eval; buys binary downloads.
    llm-agents.url = "github:numtide/llm-agents.nix";

    agent-of-empires.url = "github:agent-of-empires/agent-of-empires";
  };

  outputs = inputs: inputs.flake-parts.lib.mkFlake {inherit inputs;} (inputs.import-tree ./modules);
}
