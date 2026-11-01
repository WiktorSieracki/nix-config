{
  flake.modules.nixos.openrouter-api = {config, ...}: let
    # sops-nix's default render path, spelled out so the shell hooks survive the
    # feature test, which stubs sops.templates away.
    envFile = "/run/secrets/rendered/openrouter-env";
  in {
    # OpenRouter API key (openrouter.ai/settings/keys) for the OpenAI-compatible
    # API at openrouter.ai/api/v1 and tools that read OPENROUTER_API_KEY.
    sops.secrets.openrouterApiKey = {owner = "wiktor";};

    sops.templates."openrouter-env" = {
      owner = "wiktor";
      content = ''
        export OPENROUTER_API_KEY=${config.sops.placeholder.openrouterApiKey}
      '';
    };

    # Readable only by its owner, so the guard keeps other accounts' shells quiet.
    # `export A=b` is valid in both sh and fish.
    environment.extraInit = ''
      [ -r ${envFile} ] && . ${envFile}
    '';
    programs.fish.interactiveShellInit = ''
      test -r ${envFile}; and source ${envFile}
    '';
  };

  # The key comes from SOPS, so the feature is not self-sufficient without it.
  flake.featureMeta.openrouter-api = {
    requires = ["sops"];
    kind = "config";
  };

  # feature test: secret-backed — SOPS stubbed (no real key in the VM), so this
  # only proves the module integrates and the shell hook tolerates a missing
  # env file instead of breaking login.
  flake.featureTests.openrouter-api = {
    extraNixosModules = [
      ({lib, ...}: {
        sops.secrets = lib.mkForce {};
        sops.templates = lib.mkForce {};
        sops.age.sshKeyPaths = lib.mkForce [];
      })
    ];
    testScript = ''
      machine.succeed("bash -lc true")
    '';
  };
}
