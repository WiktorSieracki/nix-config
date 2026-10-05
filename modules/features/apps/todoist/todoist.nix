let
  # nixpkgs' todoist-electron only appends the Ozone/Wayland flags when
  # NIXOS_OZONE_WL is set; without it the AppImage's Electron falls back to
  # XWayland (blurry on HiDPI, no Wayland IME). Bake the variable into the
  # package so both the niri bind and the .desktop entry (Exec=todoist-electron,
  # resolved off PATH) get a Wayland-native session. Same trick as discord.
  mkTodoistApp = pkgs:
    pkgs.symlinkJoin {
      name = "todoist-electron-wayland";
      paths = [pkgs.todoist-electron];
      nativeBuildInputs = [pkgs.makeWrapper];
      postBuild = ''
        wrapProgram $out/bin/todoist-electron --set NIXOS_OZONE_WL 1
      '';
      meta = pkgs.todoist-electron.meta // {mainProgram = "todoist-electron";};
    };
in {
  flake.niriBinds.todoist = {
    pkgs,
    lib,
  }: {
    "Mod+T" = _: {
      props."hotkey-overlay-title" = "Open Todoist";
      content."spawn" = ["${lib.getExe (mkTodoistApp pkgs)}"];
    };
  };

  flake.modules.nixos.todoist = {pkgs, ...}: {
    environment.systemPackages = [
      (mkTodoistApp pkgs)
      # CLI client (`todoist list`, `todoist add ...`); needs an API token on
      # first use — see notes.md.
      pkgs.todoist
    ];
  };

  flake.featureMeta.todoist = {
    requires = ["desktop"];
    kind = "gui";
    provides.systemBins = ["todoist-electron" "todoist"];
  };

  # feature test: nixpkgs.config.allowUnfree is already true in the outer perSystem
  # pkgs (parts.nix), so no extra module is needed. `provides` covers both
  # binaries; the script guards the Wayland wrapper and the CLI's cold start.
  flake.featureTests.todoist = {
    testScript = ''
      # The Wayland flags hang off this variable, so guard the wrapper that sets it.
      machine.succeed("grep -q NIXOS_OZONE_WL $(command -v todoist-electron)")
      # The CLI must come up without a config file or a token present.
      machine.succeed("todoist --help")
    '';
  };
}
