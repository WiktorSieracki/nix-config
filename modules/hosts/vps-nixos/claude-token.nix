{
  # Claude Code on a headless box. `claude auth login` there needs its OAuth
  # code pasted back into the terminal, which kept failing ("Invalid code",
  # "Login failed: 400" — 2026-11-01). So the VPS runs on a long-lived token
  # from `claude setup-token`, minted on the desktop (where the browser
  # callback needs no paste) and stored in secrets-vps.yaml. Claude Code
  # reads it from CLAUDE_CODE_OAUTH_TOKEN; it is valid for a year — renew
  # with `claude setup-token` + `sops secrets-vps.yaml` (notes.md).
  flake.modules.nixos."hosts/vpsNixos" = {config, ...}: let
    shellEnv = "/run/secrets/rendered/claude-oauth-env";
  in {
    sops.secrets.claudeCodeOauthToken = {owner = "wiktor";};

    sops.templates = {
      # Shells: `export A=b` is valid in both sh and fish.
      "claude-oauth-env" = {
        owner = "wiktor";
        content = ''
          export CLAUDE_CODE_OAUTH_TOKEN=${config.sops.placeholder.claudeCodeOauthToken}
        '';
      };
      # systemd's EnvironmentFile syntax has no `export`.
      "claude-oauth-systemd" = {
        owner = "wiktor";
        content = ''
          CLAUDE_CODE_OAUTH_TOKEN=${config.sops.placeholder.claudeCodeOauthToken}
        '';
      };
    };

    environment.extraInit = ''
      [ -r ${shellEnv} ] && . ${shellEnv}
    '';
    programs.fish.interactiveShellInit = ''
      test -r ${shellEnv}; and source ${shellEnv}
    '';

    # The providers t3code spawns inherit the unit's environment. `-`: a
    # missing file (secrets not decrypted yet) must not stop the server.
    home-manager.users.wiktor.systemd.user.services.t3code.Service.EnvironmentFile = [
      "-${config.sops.templates."claude-oauth-systemd".path}"
    ];
  };
}
