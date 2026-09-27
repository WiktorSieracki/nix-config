{
  # Android in an LXC container, drawn natively on Wayland (niri). Used to run
  # Android games next to the desktop; the kernel ships binderfs built in.
  flake.modules.nixos.waydroid = {pkgs, ...}: {
    virtualisation.waydroid = {
      enable = true;
      # waydroid-net.sh prefers iptables-legacy, but this kernel only ships the
      # nf_tables backend (no ip_tables module), so the session fails to start.
      # Use iptables-nft, the same backend the NixOS firewall uses.
      package = pkgs.waydroid.overrideAttrs (old: {
        postPatch =
          (old.postPatch or "")
          + ''
            substituteInPlace data/scripts/waydroid-net.sh \
              --replace-fail 'command -v iptables-legacy' 'command -v iptables-nft' \
              --replace-fail 'command -v ip6tables-legacy' 'command -v ip6tables-nft'
          '';
      });
    };
  };

  flake.featureMeta.waydroid = {
    requires = ["desktop"];
    kind = "service";
    # The container needs binder and a downloaded Android image, neither of which
    # exists in the headless test VM.
    runtimeUntestable = true;
    provides.systemBins = ["waydroid"];
  };

  # feature test: only the CLI is assertable; `waydroid-container` would fail to
  # start without `waydroid init` having downloaded an image.
  flake.featureTests.waydroid = {
    testScript = ''
      machine.succeed("waydroid --version")
    '';
  };
}
