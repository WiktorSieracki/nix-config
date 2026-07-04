{
  flake.modules.nixos.cachix = {pkgs, ...}: let
    cache-push = pkgs.writeShellApplication {
      name = "cache-push";
      runtimeInputs = with pkgs; [cachix jq];
      text = builtins.readFile ./cache-push.sh;
    };
  in {
    # Pull side: every machine substitutes from the personal cache. The cache
    # is public, so no auth is needed for downloads.
    nix.settings.substituters = ["https://wiktor-nixos.cachix.org"];
    nix.settings.trusted-public-keys = [
      "wiktor-nixos.cachix.org-1:3DOZHbBhM0h+YZFUZ1zZikBSLC7cTbZglgQEhF7Gi2M="
    ];

    # Push side: `cache-push` uploads locally-built paths after a rebuild.
    # The write token lives in secrets.yaml; CI uses its own copy from the
    # CACHIX_AUTH_TOKEN GitHub secret.
    sops.secrets.cachixAuthToken = {owner = "wiktor";};

    environment.systemPackages = [
      pkgs.cachix
      cache-push
    ];
  };

  # The push token comes from SOPS, so the feature is not self-sufficient
  # without it — same hidden-dependency reasoning as git's user.email.
  flake.featureMeta.cachix = {
    requires = ["sops"];
    kind = "cli";
  };

  # Próba: secret-backed feature — per ADR 0002 (b) we stub every SOPS
  # secret (no real key in the VM) and assert the CLIs land on PATH. The
  # actual upload needs network + a real token, so runtime push is out of
  # scope; we do assert cache-push fails *gracefully* when the token file
  # is absent (its first guard) instead of crashing later mid-push.
  flake.probaTests.cachix = {
    extraNixosModules = [
      ({lib, ...}: {
        sops.secrets = lib.mkForce {};
        sops.templates = lib.mkForce {};
        sops.age.sshKeyPaths = lib.mkForce [];
      })
    ];
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("command -v cachix")
      machine.succeed("command -v cache-push")
      machine.fail("cache-push")
      # `|| true` neutralizes cache-push's exit 1 — the test shell runs with
      # pipefail, which would otherwise fail the pipeline despite grep matching.
      machine.succeed("(cache-push 2>&1 || true) | grep -q 'cannot read /run/secrets/cachixAuthToken'")
    '';
  };
}
