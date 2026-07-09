{config, ...}: {
  # Zed editor configured for wiktor: custom noctalia theme, nix/toml/catppuccin
  # extensions, copilot predictions, direnv integration. HM-only feature.
  flake.featureMeta.zeditor = {
    requires = [];
    kind = "gui";
  };

  # Próba: zeditor binary is in wiktor's profile PATH.
  flake.probaTests.zeditor = {
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("home-manager-proba.service")
      machine.succeed("su - proba -c 'command -v zeditor'")
    '';
  };

  flake.modules.homeManager.zeditor = {
    pkgs,
    lib,
    ...
  }: {
    xdg.configFile."zed/themes/noctalia.json".source = ./noctalia.json;

    programs.zed-editor = {
      enable = true;

      # This populates the userSettings "auto_install_extensions"
      extensions = [
        "nix"
        "toml"
        "catppuccin-icons"
      ];

      # Everything inside of these brackets are Zed options
      userSettings = {
        session = {
          trust_all_worktrees = true;
        };
        edit_predictions = {
          provider = "copilot";
        };
        agent = {
          play_sound_when_agent_done = true;
        };
        diagnostics = {
          button = true;
          include_warnings = true;
          inline = {
            enabled = true;
            update_debounce_ms = 150;
            padding = 4;
            min_column = 0;
            max_severity = null;
          };
        };

        node = {
          path = lib.getExe pkgs.nodejs;
          npm_path = lib.getExe' pkgs.nodejs "npm";
        };

        auto_update = false;

        terminal = {
          alternate_scroll = "off";
          blinking = "off";
          copy_on_select = false;
          dock = "bottom";
          detect_venv = {
            on = {
              directories = [
                ".env"
                "env"
                ".venv"
                "venv"
              ];
              activate_script = "default";
            };
          };
          env = {
            TERM = "${config.flake.meta.programs.terminal}";
          };
          font_family = "DejaVu Sans Mono";
          font_features = null;
          font_size = null;
          line_height = "comfortable";
          option_as_meta = false;
          button = false;
          shell = "system";
          # shell = {
          #   program = "zsh";
          # };
          working_directory = "current_project_directory";
        };

        lsp = {
        };

        languages = {
          #   "Elixir" = {
          #     language_servers = ["!lexical" "elixir-ls" "!next-ls"];
          #     format_on_save = {
          #       external = {
          #         command = "mix";
          #         arguments = ["format" "--stdin-filename" "{buffer_path}" "-"];
          #       };
          #     };
          #   };

          #   "HEEX" = {
          #     language_servers = ["!lexical" "elixir-ls" "!next-ls"];
          #     format_on_save = {
          #       external = {
          #         command = "mix";
          #         arguments = ["format" "--stdin-filename" "{buffer_path}" "-"];
          #       };
          #     };
          #   };
        };

        # vim_mode = true;

        # Tell Zed to use direnv and direnv can use a flake.nix environment
        load_direnv = "shell_hook";
        base_keymap = "VSCode";

        theme = {
          mode = "system";
          light = "Noctalia Light";
          dark = "Noctalia Dark";
        };

        show_whitespaces = "all";
        ui_font_size = 16;
        buffer_font_size = 16;
      };
    };
  };
}
