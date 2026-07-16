{inputs, ...}: {
  flake.modules = {
    nixos.sops = {pkgs, ...}: {
      imports = [
        inputs.sops-nix.nixosModules.sops
      ];

      environment.systemPackages = with pkgs; [
        sops
      ];

      sops = {
        # The age key file used to decrypt secrets (your user key for SOPS CLI)
        age.sshKeyPaths = ["/home/wiktor/.ssh/id_ed25519"];

        # The default sops file to use for secrets
        # NB: relative to this file. After folderizing into sops/, the repo-root
        # secrets.yaml is three levels up (sops/ → features/ → modules/ → root).
        defaultSopsFile = ../../../secrets.yaml;
        validateSopsFiles = false;

        secrets = {
          eduroamPassword = {};
          studentEmail = {};
          personalEmail = {owner = "wiktor";};
        };

        # someOption = config.sops.secrets.hello.path;
        # if home-manager switch fails because of sops try running:
        # systemctl --user reset-failed
      };
    };
    # NOTE: no homeManager part on purpose (ADR 0004). HM-level sops-nix would
    # decrypt with wiktor's ssh key — unreadable for any other account (home
    # 700). Per-user secrets are delivered by *system* sops with `owner`
    # instead (see git's email templates), so the HM half died with its last
    # consumer.
  };

  # sops decrypts secrets with wiktor's real ssh key — absent in any VM. So the
  # runtime (actual decryption) is untestable here; the feature test only proves the
  # module integrates and boots with secrets stubbed, and the `sops` CLI is
  # present. runtimeUntestable = honest (c)-escape-hatch flag (ADR 0002 Q8).
  flake.featureMeta.sops = {
    requires = [];
    kind = "config";
    runtimeUntestable = true;
  };

  flake.featureTests.sops = {
    extraNixosModules = [
      ({lib, ...}: {
        sops.secrets = lib.mkForce {};
        sops.templates = lib.mkForce {};
        sops.age.sshKeyPaths = lib.mkForce [];
      })
    ];
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("command -v sops")
    '';
  };
}
