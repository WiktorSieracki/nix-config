{
  config,
  lib,
  ...
}: let
  usersMeta = config.flake.meta.users or {};
in {
  flake.modules = {
    # User-agnostic (ADR 0004): identity comes injected as `userMeta`, never a
    # hardcoded login. The email is a *secret*, delivered by a system-level
    # sops template rendered per user (owner = that user) — HM-level sops
    # can't work here, since it would decrypt with another account's key.
    homeManager.git = {
      userMeta,
      osConfig ? null,
      lib,
      ...
    }: {
      programs.git = {
        enable = true;
        signing.format = null;
        includes = lib.optional (userMeta ? emailSecret) {
          path = osConfig.sops.templates."git-email-${userMeta.login}".path;
        };

        settings.user = {
          name = userMeta.fullName;
        };
      };
    };

    # The NixOS part renders one email template per account that enables git
    # on this host (`hostUsers` is injected by the loader) and has an
    # emailSecret in flake.meta.users.
    nixos.git = {
      pkgs,
      config,
      lib,
      hostUsers ? {},
      ...
    }: let
      gitUsers =
        lib.filter (
          u: builtins.elem "git" hostUsers.${u} && (usersMeta.${u} or {}) ? emailSecret
        ) (builtins.attrNames hostUsers);
    in {
      environment.systemPackages = with pkgs; [
        gh
      ];

      sops.secrets = lib.genAttrs (map (u: usersMeta.${u}.emailSecret) gitUsers) (_: {});
      sops.templates = lib.listToAttrs (map (u: {
        name = "git-email-${u}";
        value = {
          content = ''
            [user]
              email = ${config.sops.placeholder.${usersMeta.${u}.emailSecret}}
          '';
          owner = u;
        };
      }) gitUsers);
    };
  };

  # git's user.email comes from SOPS templates whose key/defaultSopsFile are
  # supplied by the `sops` feature — so git is NOT self-sufficient without it.
  # Declaring that here makes the hidden dependency explicit. Kind `cli`.
  flake.featureMeta.git = {
    requires = ["sops"];
    kind = "cli";
  };

  # Próba (Tier 1). git is secret-backed: the VM has no real SOPS key, so per
  # ADR 0002 (b) we *stub* — blank every SOPS secret/template so the VM boots,
  # and inject the email via a plaintext include. We then assert what actually
  # matters: git & gh run, user.name comes from the injected userMeta (the
  # neutral test identity — a hardcoded real name would fail here), and the
  # include lands. (Real SOPS decryption is sops-nix's job, not git's.)
  flake.featureTests.git = {
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
        programs.git.includes = lib.mkForce [
          {path = "${pkgs.writeText "git-email.inc" "[user]\n\temail = test@example.test\n"}";}
        ];
      })
    ];
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("home-manager-tester.service")
      machine.succeed("su - tester -c 'gh --version'")
      machine.succeed("su - tester -c 'git --version'")
      machine.succeed("su - tester -c 'git config --get user.name' | grep -q 'Test User'")
      machine.succeed("su - tester -c 'git config --get user.email' | grep -q 'test@example.test'")
    '';
  };
}
