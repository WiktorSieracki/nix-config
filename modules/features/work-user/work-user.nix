{
  flake.modules.nixos.work-user = {pkgs, ...}: {
    users.users.work = {
      isNormalUser = true;
      description = "Work";
      # Isolation by omission: no `wheel` (no sudo) and no extra groups.
      # The home dir gets the NixOS default homeMode "700", so `work` and
      # `wiktor` cannot read each other's files.
      initialPassword = "work";
      # Per-user packages land in /etc/profiles/per-user/work — only in this
      # user's PATH and app launcher, invisible to wiktor's session.
      packages = with pkgs; [
        slack
        vscode
        google-chrome
      ];
    };
  };

  # Requires `wiktor` because the point of the feature is isolation *from* the
  # main user — the Próba asserts that boundary, so wiktor must exist in the VM.
  flake.featureMeta.work-user = {
    requires = ["wiktor"];
    kind = "gui";
  };

  flake.probaTests.work-user = {
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("getent passwd work")

      # Work apps are in work's PATH (per-user profile)...
      machine.succeed("su - work -c 'command -v slack'")
      machine.succeed("su - work -c 'command -v code'")
      machine.succeed("su - work -c 'command -v google-chrome-stable'")
      # ...but NOT in wiktor's.
      machine.fail("su - wiktor -c 'command -v slack'")

      # Isolation: no wheel membership, no sudo.
      machine.fail("id -nG work | grep -qw wheel")
      machine.fail("su - work -c 'sudo -n true'")

      # Isolation: work cannot read wiktor's home (homeMode 700).
      machine.fail("su - work -c 'ls /home/wiktor'")
    '';
  };
}
