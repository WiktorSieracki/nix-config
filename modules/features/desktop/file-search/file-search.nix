# File search in the noctalia launcher: type `>file <query>` in Mod+Space.
# The plugin is `file-search` from the official noctalia v4 plugin registry,
# pinned to a commit. Its defaults call bare `fd` / `xdg-open`, which resolve
# against whatever PATH niri started noctalia with — so they are rewritten to
# store paths here, and the plugin keeps working regardless of that PATH.
{...}: let
  mkFileSearchPlugin = pkgs: let
    registry = pkgs.fetchFromGitHub {
      owner = "noctalia-dev";
      repo = "noctalia-plugins";
      rev = "ea21cb63d063075bc0acd72d8b946ce2c5eef00d";
      hash = "sha256-M+7SLW+wI3KvDMj8dSrW/uUmpPiYhsXA2jpbbgL5imk=";
    };
  in
    pkgs.runCommand "noctalia-plugin-file-search" {nativeBuildInputs = [pkgs.jq];} ''
      cp -r ${registry}/file-search $out
      chmod -R u+w $out
      jq '.metadata.defaultSettings += {
            fdCommand: "${pkgs.fd}/bin/fd",
            fileOpener: "${pkgs.xdg-utils}/bin/xdg-open"
          }' ${registry}/file-search/manifest.json > $out/manifest.json
    '';
in {
  # fd is also handy on its own in the terminal.
  flake.modules.nixos.file-search = {pkgs, ...}: {
    environment.systemPackages = [pkgs.fd];
  };

  flake.modules.homeManager.file-search = {
    config,
    lib,
    pkgs,
    ...
  }: {
    # Linked file by file (`recursive`) so the directory stays writable for the
    # settings.json noctalia keeps next to the plugin.
    xdg.configFile."noctalia/plugins/file-search" = {
      source = mkFileSearchPlugin pkgs;
      recursive = true;
    };

    # noctalia loads only plugins flagged enabled in its runtime plugins.json
    # (see the same hook in apps/todoist/todoist.nix).
    home.activation.enableFileSearchNoctaliaPlugin = lib.hm.dag.entryAfter ["writeBoundary"] ''
      f="${config.xdg.configHome}/noctalia/plugins.json"
      run mkdir -p "$(dirname "$f")"
      [ -s "$f" ] || run ${pkgs.coreutils}/bin/cp ${pkgs.writeText "plugins.json" ''{"version":2,"states":{},"sources":[]}''} "$f"
      run ${pkgs.coreutils}/bin/chmod u+w "$f"
      tmp=$(${pkgs.coreutils}/bin/mktemp)
      ${lib.getExe pkgs.jq} '.states["file-search"] = ((.states["file-search"] // {}) + {enabled: true})' "$f" > "$tmp"
      run ${pkgs.coreutils}/bin/mv "$tmp" "$f"
    '';
  };

  flake.featureMeta.file-search = {
    requires = ["desktop"];
    kind = "gui";
    provides = {
      systemBins = ["fd"];
      userFiles = [
        "~/.config/noctalia/plugins/file-search/manifest.json"
        "~/.config/noctalia/plugins/file-search/LauncherProvider.qml"
      ];
    };
  };

  # feature test: `provides` covers fd and the plugin files. The script checks
  # that the baked fd/xdg-open paths are real, that fd actually finds a file,
  # and that the plugin is flagged enabled.
  flake.featureTests.file-search = {
    testScript = ''
      manifest = "/home/tester/.config/noctalia/plugins/file-search/manifest.json"
      fd = machine.succeed(f"jq -r .metadata.defaultSettings.fdCommand {manifest}").strip()
      opener = machine.succeed(f"jq -r .metadata.defaultSettings.fileOpener {manifest}").strip()
      assert fd.startswith("/nix/store/"), fd
      machine.succeed(f"test -x {opener}")
      # The query the plugin runs: a substring of a file under ~.
      machine.succeed("su - tester -c 'touch ~/plik-testowy.txt'")
      machine.succeed(f"su - tester -c '{fd} --type f plik-testowy ~' | grep -q plik-testowy.txt")
      machine.succeed("su - tester -c \"jq -e '.states[\\\"file-search\\\"].enabled == true' ~/.config/noctalia/plugins.json\"")
      machine.succeed("su - tester -c 'touch ~/.config/noctalia/plugins/file-search/settings.json'")
    '';
    extraNixosModules = [
      ({pkgs, ...}: {environment.systemPackages = [pkgs.jq];})
    ];
  };
}
