{...}: let
  # Shared by the host and by the VM test below, so the test exercises this
  # exact code rather than a copy of it.
  guardModule = {
    config,
    lib,
    pkgs,
    ...
  }: let
    autoLogin = config.services.displayManager.autoLogin;
    keyringUser = autoLogin.user;

    # `sddm` substacks `login`, as does tty login, so guarding `login` covers
    # every path on this host that can hand gkr-pam a password.
    authRules = config.security.pam.services.login.rules.auth;
    guardName = "skip-gnome-keyring";

    enabledAuth =
      lib.sort (a: b: a.order < b.order)
      (lib.filter (r: r.enable) (lib.attrValues authRules));
    authNames = map (r: r.name) enabledAuth;
    indexOf = name: lib.lists.findFirstIndex (n: n == name) null authNames;
    guardIndex = indexOf guardName;
    keyringIndex = indexOf "gnome_keyring";
  in {
    config = lib.mkIf autoLogin.enable {
      # `[success=1 default=ignore]` is a jump: on PAM_SUCCESS (we are the
      # autologin user) skip exactly the next module in the stack; on anything
      # else fall through unchanged, so other accounts keep their normal
      # keyring unlock. The jump counts modules, not orders, which is why the
      # assertion below pins the two rules as neighbours.
      security.pam.services.login.rules.auth.${guardName} = {
        # Immediately ahead of gnome_keyring (12200) and behind unix-early
        # (11700). Derived, not literal, so an upstream reshuffle moves it too.
        order = authRules.gnome_keyring.order - 50;
        control = "[success=1 default=ignore]";
        modulePath = "${pkgs.linux-pam}/lib/security/pam_succeed_if.so";
        # `=` is pam_succeed_if's string comparison; `eq` is numeric and
        # silently never matches a login name ("wiktor" is not a number).
        args = ["quiet" "user" "=" keyringUser];
      };

      # A jump that lands on the wrong module is worse than no jump: skipping
      # `pam_unix.so` (sufficient) instead of gnome_keyring drops the stack
      # through to `pam_deny.so`, and this account can no longer log in at the
      # greeter or on a tty. Fail the build instead of shipping that.
      assertions = [
        {
          assertion = guardIndex != null && keyringIndex != null && keyringIndex == guardIndex + 1;
          message = ''
            pam: '${guardName}' must sit immediately before 'gnome_keyring' in
            the auth stack of service 'login', because its control is a
            one-module jump. Current enabled auth order:
            ${lib.concatStringsSep ", " authNames}.
          '';
        }
      ];
    };
  };
in {
  # Keep PAM's hands off the autologin account's login keyring.
  #
  # Host-level, not a feature, for the same reason as autologin.nix: the policy
  # names a login, which features are explicitly built not to hardcode. It is
  # the direct consequence of autologin.nix and only makes sense
  # next to it — it reads the account straight off that option rather than
  # naming it a second time.
  #
  # The problem it solves:
  #
  #   `sddm-autologin`'s auth stack ends in `pam_permit.so`, so no password ever
  #   reaches `pam_gnome_keyring.so`. A password-protected
  #   `~/.local/share/keyrings/login.keyring` therefore stays locked, and the
  #   first Secret Service client in the session (localsend, via libsecret)
  #   raises a gcr password dialog on the bare wallpaper. Autologin and an
  #   encrypted login keyring are mutually exclusive; the keyring is the half
  #   that gives way, so it is kept passwordless (plaintext `[keyring]` format).
  #
  #   That alone is not stable. The account still reaches the SDDM greeter
  #   regularly — logging out to switch to `work` drops you there, since
  #   `sddm.autoLogin.relogin` is false. On such a login gkr-pam does get a
  #   password, and on 2026-10-09 18:27 it adopted it as the login keyring's
  #   master and re-encrypted the file, resurrecting the dialog at the next boot
  #   (2026-10-10 08:47). The 2026-09-22 conversion to plaintext was one-shot
  #   imperative state with nothing holding it in place.
  #
  # So cut the vector instead of re-running the conversion: skip
  # `pam_gnome_keyring.so` in the auth stack for this one account, and no
  # password can ever reach it again. Every other account (notably `work`,
  # whose keyring is encrypted and wants unlocking) is untouched.
  #
  # Only the auth stack needs this. `password` has `pam_unix.so` as `sufficient`
  # ahead of gnome_keyring, so a successful password change short-circuits the
  # stack and gnome_keyring never runs; `session` only carries `auto_start`,
  # which starts the daemon and is wanted. With the auth module skipped there is
  # no stashed password for auto_start to unlock with.
  flake.modules.nixos."hosts/desktopNixos".imports = [guardModule];

  # Behavioural, not textual: an earlier version of this check grepped the
  # rendered /etc/pam.d/login and passed happily while the guard used `eq` (and
  # then `streq`), neither of which ever matched. So drive real PAM in a VM.
  #
  # Neutral accounts, as in the feature tests: `tester` plays the autologin
  # account, `other` plays `work`. Asserts, through the `login` service:
  #   - the autologin account authenticates with its password — the jump lands
  #     on pam_unix, not past it (locked out) …
  #   - … and is still refused with a wrong one — nor past pam_deny (bypass);
  #   - gkr-pam never runs for it, so it can never re-key the keyring;
  #   - gkr-pam still runs for every other account.
  # The host-specific half — that nothing on desktopNixos lands between the
  # guard and gnome_keyring — is the eval-time assertion, which fires on every
  # build of the host.
  perSystem = {pkgs, ...}: {
    checks.host-desktop-keyring-pam = pkgs.testers.runNixOSTest {
      name = "host-desktop-keyring-pam";
      nodes.machine = {pkgs, ...}: {
        imports = [guardModule];
        services.gnome.gnome-keyring.enable = true;
        services.displayManager.autoLogin = {
          enable = true;
          user = "tester";
        };
        users.users = {
          tester = {
            isNormalUser = true;
            password = "tester-pw";
          };
          other = {
            isNormalUser = true;
            password = "other-pw";
          };
        };
        environment.systemPackages = [pkgs.pamtester];
      };
      testScript = ''
        machine.wait_for_unit("multi-user.target")

        def auth(user, password):
            """Authenticate through `login`; return (ok, gkr-pam ran)."""
            cursor = machine.succeed(
                "journalctl -n0 --show-cursor | sed -n 's/^-- cursor: //p'"
            ).strip()
            status, _ = machine.execute(
                f"echo {password} | pamtester login {user} authenticate"
            )
            machine.succeed("journalctl --sync")
            logs = machine.succeed(
                f"journalctl --after-cursor='{cursor}' SYSLOG_IDENTIFIER=pamtester -o cat"
            )
            return status == 0, "gkr-pam" in logs

        ok, gkr = auth("tester", "tester-pw")
        assert ok, "autologin account must still authenticate (jump landed past pam_unix)"
        assert not gkr, "gkr-pam ran for the autologin account; the guard does not match"

        ok, gkr = auth("tester", "wrong")
        assert not ok, "wrong password accepted; the jump skipped pam_deny"
        assert not gkr, "gkr-pam ran for the autologin account on a failed login"

        ok, gkr = auth("other", "other-pw")
        assert ok, "other accounts must authenticate normally"
        assert gkr, "gkr-pam must still run for other accounts"
      '';
    };
  };
}
