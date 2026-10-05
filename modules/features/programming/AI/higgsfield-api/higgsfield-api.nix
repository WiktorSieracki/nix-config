{
  flake.modules.nixos.higgsfield-api = {config, ...}: let
    # sops-nix's default render path, spelled out so the shell hooks survive the
    # feature test, which stubs sops.templates away.
    envFile = "/run/secrets/rendered/higgsfield-env";
  in {
    # Higgsfield platform API key (open.higgsfield.ai/api-keys) for the REST API
    # and SDKs. The `higgsfield` CLI does not use it — it logs in via OAuth.
    # The key is an id + secret pair; both live in secrets.yaml.
    sops.secrets.higgsfieldApiKeyId = {owner = "wiktor";};
    sops.secrets.higgsfieldApiKeySecret = {owner = "wiktor";};

    # Exported in both forms the docs/SDKs use: the split pair and the
    # combined `id:secret` HF_KEY.
    sops.templates."higgsfield-env" = {
      owner = "wiktor";
      content = ''
        export HF_API_KEY_ID=${config.sops.placeholder.higgsfieldApiKeyId}
        export HF_API_KEY_SECRET=${config.sops.placeholder.higgsfieldApiKeySecret}
        export HF_KEY=${config.sops.placeholder.higgsfieldApiKeyId}:${config.sops.placeholder.higgsfieldApiKeySecret}
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
  flake.featureMeta.higgsfield-api = {
    requires = ["sops"];
    kind = "config";
  };

  # feature test: secret-backed — SOPS stubbed (no real key in the VM), so this
  # only proves the module integrates and the shell hook tolerates a missing
  # env file instead of breaking login.
  flake.featureTests.higgsfield-api = {
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
