{
  flake.niriBinds.personal-snippets = {pkgs, ...}: {
    "Mod+Ctrl+N".spawn-sh = "${pkgs.wtype}/bin/wtype 'Wiktor Sieracki'";
    "Mod+Ctrl+E".spawn-sh = "${pkgs.wtype}/bin/wtype \"$(cat /run/secrets/personalEmail)\"";
    "Mod+Ctrl+G".spawn-sh = "${pkgs.wtype}/bin/wtype 'https://github.com/WiktorSieracki'";
    "Mod+Ctrl+I".spawn-sh = "${pkgs.wtype}/bin/wtype 'https://www.linkedin.com/in/wiktor-sieracki/'";
  };

  # Personal identity snippets typed via niri keybinds (wtype). kind `gui`: the
  # binds only make sense inside the niri session (hence `requires` desktop), and
  # the email snippet reads the `personalEmail` SOPS secret at runtime (hence
  # `requires` sops). runtimeUntestable: the payoff — typing into a focused
  # window using a decrypted secret — can't be exercised in a headless VM.
  flake.featureMeta.personal-snippets = {
    requires = ["desktop" "sops"];
    kind = "gui";
    runtimeUntestable = true;
  };

  # feature test: build-only (runtimeUntestable). Boots the desktop closure with
  # SOPS stubbed (no key in the VM, per ADR 0002 (b)); a green run proves the
  # snippet keybinds compile into the niri package — a broken `wtype`/pkgs
  # reference would fail the myNiri build and take the VM down with it.
  flake.featureTests.personal-snippets = {
    extraNixosModules = [
      ({lib, ...}: {
        sops.secrets = lib.mkForce {};
        sops.templates = lib.mkForce {};
        sops.age.sshKeyPaths = lib.mkForce [];
      })
    ];
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("command -v niri")
    '';
  };
}
