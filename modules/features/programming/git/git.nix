{inputs, ...}: {
  flake.modules = {
    homeManager.git = {config, ...}: {
      imports = [
        inputs.sops-nix.homeManagerModules.sops
      ];

      sops.secrets.studentEmail = {};

      sops.templates."git-user-email".content = ''
        [user]
          email = ${config.sops.placeholder.studentEmail}
      '';

      programs.git = {
        enable = true;
        signing.format = null;
        includes = [
          {
            path = config.sops.templates."git-user-email".path;
          }
        ];

        settings.user = {
          name = "Wiktor Sieracki";
        };
      };
    };

    nixos.git = {pkgs, ...}: {
      environment.systemPackages = with pkgs; [
        gh
      ];
    };
  };

  # git's user.email comes from a SOPS template whose key/defaultSopsFile are
  # supplied by the `sops` feature — so git is NOT self-sufficient without it.
  # Declaring that here makes the hidden dependency explicit (the loader would
  # hard-fail a host that enabled git without sops). Kind `cli`: git/gh on PATH.
  flake.featureMeta.git = {
    requires = ["wiktor" "sops"];
    kind = "cli";
  };

  # Próba (Tier 1). git is secret-backed: the VM has no real SOPS key, so per
  # ADR 0002 (b) we *stub* — blank every SOPS secret/template (both system and
  # HM) so the VM boots, and inject the email via a plaintext include. We then
  # assert what actually matters: git & gh run and the config lands correctly.
  # (Real SOPS decryption is sops-nix's job, not git's, so we don't test it.)
  flake.probaTests.git = {
    extraNixosModules = [
      ({lib, ...}: {
        sops.secrets = lib.mkForce {};
        sops.templates = lib.mkForce {};
        sops.age.sshKeyPaths = lib.mkForce [];
      })
    ];
    extraHmModules = [
      ({
        lib,
        pkgs,
        ...
      }: {
        sops.secrets = lib.mkForce {};
        sops.templates = lib.mkForce {};
        sops.age.sshKeyPaths = lib.mkForce [];
        programs.git.includes = lib.mkForce [
          {path = "${pkgs.writeText "git-email.inc" "[user]\n\temail = test@example.test\n"}";}
        ];
      })
    ];
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("home-manager-wiktor.service")
      machine.succeed("su - wiktor -c 'gh --version'")
      machine.succeed("su - wiktor -c 'git --version'")
      machine.succeed("su - wiktor -c 'git config --get user.name' | grep -q 'Wiktor Sieracki'")
      machine.succeed("su - wiktor -c 'git config --get user.email' | grep -q 'test@example.test'")
    '';
  };
}
