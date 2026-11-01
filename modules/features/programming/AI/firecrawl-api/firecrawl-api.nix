{
  flake.modules.nixos.firecrawl-api = {config, ...}: let
    # sops-nix's default render path, spelled out so the shell hooks survive the
    # feature test, which stubs sops.templates away.
    envFile = "/run/secrets/rendered/firecrawl-env";
  in {
    # Firecrawl API key (firecrawl.dev/app/api-keys) for the REST API, SDKs,
    # the `firecrawl` CLI and the firecrawl MCP server.
    sops.secrets.firecrawlApiKey = {owner = "wiktor";};

    sops.templates."firecrawl-env" = {
      owner = "wiktor";
      content = ''
        export FIRECRAWL_API_KEY=${config.sops.placeholder.firecrawlApiKey}
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
  flake.featureMeta.firecrawl-api = {
    requires = ["sops"];
    kind = "config";
  };

  # feature test: secret-backed — SOPS stubbed (no real key in the VM), so this
  # only proves the module integrates and the shell hook tolerates a missing
  # env file instead of breaking login.
  flake.featureTests.firecrawl-api = {
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
