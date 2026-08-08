let
  # nixpkgs' Discord wrapper only appends the Ozone/Wayland flags when
  # NIXOS_OZONE_WL is set; without it Electron falls back to X11 and screen
  # sharing captures a dead XWayland root window. Bake the variable into the
  # package so both the niri bind and the .desktop entry (Exec=Discord, resolved
  # off PATH) get a Wayland-native session. See notes.md.
  mkDiscord = pkgs:
    pkgs.symlinkJoin {
      name = "discord-wayland";
      paths = [pkgs.discord];
      nativeBuildInputs = [pkgs.makeWrapper];
      postBuild = ''
        wrapProgram $out/bin/Discord --set NIXOS_OZONE_WL 1
      '';
      meta = pkgs.discord.meta // {mainProgram = "Discord";};
    };
in {
  flake.niriBinds.discord = {
    pkgs,
    lib,
  }: {
    "Mod+D" = _: {
      props."hotkey-overlay-title" = "Open Discord";
      content."spawn" = ["${lib.getExe (mkDiscord pkgs)}"];
    };
  };

  flake.modules.nixos.discord = {pkgs, ...}: {
    environment.systemPackages = [(mkDiscord pkgs)];
  };

  flake.featureMeta.discord = {
    requires = ["desktop"];
    kind = "gui";
    # Binary is `Discord` (capital D).
    provides.systemBins = ["Discord"];
  };

  # feature test: nixpkgs.config.allowUnfree is already true in the outer perSystem pkgs
  # (parts.nix), so no extra module is needed. `provides` covers the binary; the
  # script guards the wrapper on top of it.
  flake.featureTests.discord = {
    testScript = ''
      # Screen sharing is dead-on-arrival unless Electron runs Wayland-native,
      # so guard the wrapper that flips it on.
      machine.succeed("grep -q NIXOS_OZONE_WL $(command -v Discord)")
    '';
  };
}
