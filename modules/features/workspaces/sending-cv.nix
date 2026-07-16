{config, ...}: let
  programs = config.flake.meta.programs;

  # Maps meta program names to the app_id niri reports for each window
  appIds = {
    brave = "brave-browser";
    code = "code";
    ghostty = "com.mitchellh.ghostty";
  };

  browserAppId = appIds.brave;
  editorAppId = appIds.${programs.editor};
  terminalAppId = appIds.${programs.terminal};
in {
  flake.modules.homeManager."sending-cv" = {...}: {
    xdg.desktopEntries."sending-cv" = {
      name = "CV Workspace";
      exec = "sending-cv";
      terminal = false;
      categories = ["Utility"];
    };
  };

  # Workspace launcher: opens browser, editor, two terminals in the right
  # niri workspaces for CV sending workflow. HM part adds a .desktop entry.
  # Needs `wiktor` for the home-manager desktop entry.
  flake.featureMeta."sending-cv" = {
    requires = [];
    kind = "cli";
  };

  # feature test: the sending-cv binary lands on PATH.
  flake.featureTests."sending-cv" = {
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("home-manager-tester.service")
      machine.succeed("command -v sending-cv")
    '';
  };

  flake.modules.nixos."sending-cv" = {pkgs, ...}: {
    environment.systemPackages = [
      (pkgs.writeShellApplication {
        name = "sending-cv";
        runtimeInputs = with pkgs; [niri jq];
        text = ''
          PROJ_DIR="$HOME/Projects/modern-cv"
          LEFT="DP-3"       # HP E243
          RIGHT="HDMI-A-1"  # ASUS VX239

          initial_ids=$(niri msg -j windows | jq -r '[.[].id | tostring] | join(" ")')

          placed=0
          terminal_placed=0
          declare -A done_ids

          # Start event stream before spawning so no window open events are missed
          exec 3< <(
            timeout 30 niri msg -j event-stream \
              | jq --unbuffered -c 'select(.WindowOpenedOrChanged) | .WindowOpenedOrChanged.window'
          )

          niri msg action spawn -- brave
          niri msg action spawn -- ${programs.editor} "$PROJ_DIR"
          niri msg action spawn -- ${programs.terminal} --working-directory="$PROJ_DIR"
          niri msg action spawn -- ${programs.terminal} --working-directory="$PROJ_DIR" -e claude --dangeroulsy-skip-permissions

          while IFS= read -r -u 3 win; do
            id=$(jq -r '.id' <<< "$win")
            app_id=$(jq -r '.app_id // empty' <<< "$win")

            [[ -z "$app_id" ]] && continue
            [[ " $initial_ids " == *" $id "* ]] && continue
            [[ -n "''${done_ids[$id]+x}" ]] && continue

            case "$app_id" in
              ${browserAppId})
                niri msg action move-window-to-monitor --id "$id" "$RIGHT"
                niri msg action focus-window --id "$id"
                niri msg action maximize-column
                done_ids[$id]=1
                placed=$((placed + 1)) ;;
              ${editorAppId})
                niri msg action move-window-to-monitor --id "$id" "$LEFT"
                done_ids[$id]=1
                placed=$((placed + 1)) ;;
              ${terminalAppId})
                if [[ $terminal_placed -lt 2 ]]; then
                  niri msg action move-window-to-monitor --id "$id" "$LEFT"
                  done_ids[$id]=1
                  terminal_placed=$((terminal_placed + 1))
                  placed=$((placed + 1))
                fi ;;
            esac

            [[ $placed -ge 4 ]] && break
          done

          exec 3<&-
        '';
      })
    ];
  };
}
