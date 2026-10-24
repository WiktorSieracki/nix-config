{config, ...}: let
  inherit (config.flake) agentSkillsLib;

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

  # The noctalia bar plugin (./noctalia-plugin). Its logic lives in todoist.js
  # and is unit-tested under node in checkPhase, and every QML file must parse,
  # so a broken plugin fails the build instead of silently vanishing from the
  # bar. `td` and the app are baked in as store paths — noctalia's PATH is
  # whatever niri was started with, and the plugin must not depend on it.
  mkNoctaliaPlugin = pkgs:
    pkgs.stdenvNoCC.mkDerivation {
      pname = "noctalia-plugin-todoist";
      version = (builtins.fromJSON (builtins.readFile ./noctalia-plugin/manifest.json)).version;
      src = ./noctalia-plugin;

      doCheck = true;
      nativeCheckInputs = [pkgs.nodejs pkgs.qt6.qtdeclarative];
      # qmlformat is a build-time check only; there is nothing to wrap.
      dontWrapQtApps = true;
      checkPhase = ''
        runHook preCheck
        node --test todoist.test.mjs
        for f in *.qml; do qmlformat "$f" > /dev/null; done
        runHook postCheck
      '';

      installPhase = ''
        runHook preInstall
        mkdir -p $out
        cp manifest.json todoist.js *.qml $out/
        substituteInPlace $out/Main.qml \
          --replace-fail '@td@' '${pkgs.lib.getExe pkgs.todoist-cli}' \
          --replace-fail '@todoistApp@' '${pkgs.lib.getExe (mkTodoistApp pkgs)}'
        runHook postInstall
      '';
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
      # Doist's official CLI (`td today`, `td add "…"`). Authenticates once via
      # `td auth login` (OAuth, token kept in the keyring) — see notes.md.
      pkgs.todoist-cli
    ];
  };

  # The bar plugin and the agents' `todo` skill — both are front-ends to the
  # same `td`, so they ship with it.
  flake.modules.homeManager.todoist = {
    config,
    lib,
    pkgs,
    ...
  }: {
    home.file = agentSkillsLib.links {todo = ./todo;};

    # Plugin files are linked one by one (`recursive`), so the plugin directory
    # itself stays writable for the settings.json noctalia keeps there. The bar
    # slot is `plugin:todoist` in noctalia.nix.
    xdg.configFile."noctalia/plugins/todoist" = {
      source = mkNoctaliaPlugin pkgs;
      recursive = true;
    };

    # noctalia discovers the directory on startup but loads only plugins
    # marked enabled in plugins.json — runtime state it rewrites itself, so it
    # can't be a store file. Merge just our flag in and leave the rest alone.
    home.activation.enableTodoistNoctaliaPlugin = lib.hm.dag.entryAfter ["writeBoundary"] ''
      f="${config.xdg.configHome}/noctalia/plugins.json"
      run mkdir -p "$(dirname "$f")"
      [ -s "$f" ] || run ${pkgs.coreutils}/bin/cp ${pkgs.writeText "plugins.json" ''{"version":2,"states":{},"sources":[]}''} "$f"
      run ${pkgs.coreutils}/bin/chmod u+w "$f"
      tmp=$(${pkgs.coreutils}/bin/mktemp)
      ${lib.getExe pkgs.jq} '.states.todoist = ((.states.todoist // {}) + {enabled: true})' "$f" > "$tmp"
      run ${pkgs.coreutils}/bin/mv "$tmp" "$f"
    '';
  };

  flake.featureMeta.todoist = {
    requires = ["desktop"];
    kind = "gui";
    provides = {
      systemBins = ["todoist-electron" "td"];
      userFiles = [
        "~/.config/noctalia/plugins/todoist/manifest.json"
        "~/.config/noctalia/plugins/todoist/Main.qml"
        "~/.claude/skills/todo/SKILL.md"
        "~/.agents/skills/todo/SKILL.md"
        "~/.gemini/skills/todo/SKILL.md"
      ];
    };
  };

  # feature test: nixpkgs.config.allowUnfree is already true in the outer perSystem
  # pkgs (parts.nix), so no extra module is needed. `provides` covers both
  # binaries, the plugin files and the skill links; the plugin's own logic tests
  # run when it is built. The script sweeps the skill roots, then guards the
  # Wayland wrapper, the CLI's cold start, and the two things the plugin needs
  # at runtime: real store paths instead of placeholders, and an enabled flag
  # in plugins.json.
  flake.featureTests.todoist = {
    testScript =
      agentSkillsLib.testScript
      + ''
        # The Wayland flags hang off this variable, so guard the wrapper that sets it.
        machine.succeed("grep -q NIXOS_OZONE_WL $(command -v todoist-electron)")
        # The CLI must come up without a config file or a token present.
        machine.succeed("td --help")
        # Without a token, td fails with the message the plugin keys "needs auth" on.
        out = machine.fail("su - tester -c 'td today --json' 2>&1")
        assert "No API token" in out, out
        # Every @placeholder@ got substituted, and the td it points at runs.
        main = "/home/tester/.config/noctalia/plugins/todoist/Main.qml"
        machine.fail(f"grep -q '\"@' {main}")
        td = machine.succeed(f"grep -oE '/nix/store/[^\"]+/bin/td' {main}").strip()
        machine.succeed(f"{td} --version")
        # noctalia only loads plugins flagged enabled in its runtime plugins.json.
        machine.succeed("su - tester -c \"jq -e '.states.todoist.enabled == true' ~/.config/noctalia/plugins.json\"")
        # The plugin directory must stay writable for its settings.json.
        machine.succeed("su - tester -c 'touch ~/.config/noctalia/plugins/todoist/settings.json'")
      '';
    extraNixosModules =
      agentSkillsLib.testModules
      ++ [
        ({pkgs, ...}: {environment.systemPackages = [pkgs.jq];})
      ];
  };
}
