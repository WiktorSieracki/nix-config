{ inputs, pkgs, ... }:

{
  programs.vscode = {
    enable = true;
    package = pkgs.vscode;

    # VS Code extensions
    extensions = with pkgs.vscode-extensions; [
      # Language support
      ms-python.python
      ms-vscode.cpptools
      bradlc.vscode-tailwindcss
      esbenp.prettier-vscode
      ms-vscode.vscode-typescript-next

      # Git integration
      eamodio.gitlens

      # Themes and UI
      github.github-vscode-theme
      pkief.material-icon-theme

      # Productivity
      ms-vscode.hexeditor
      ms-vscode-remote.remote-ssh
      ms-vscode-remote.remote-containers

      # Nix support
      bbenoist.nix
      jnoortheen.nix-ide
    ];

    # VS Code settings
    userSettings = {
      "editor.fontSize" = 14;
      "editor.fontFamily" = "'JetBrains Mono', 'Cascadia Code', 'Fira Code', monospace";
      "editor.fontLigatures" = true;
      "editor.tabSize" = 2;
      "editor.insertSpaces" = true;
      "editor.wordWrap" = "on";
      "editor.minimap.enabled" = false;
      "editor.formatOnSave" = true;
      "editor.codeActionsOnSave" = {
        "source.organizeImports" = "explicit";
      };

      "workbench.colorTheme" = "GitHub Dark";
      "workbench.iconTheme" = "material-icon-theme";
      "workbench.startupEditor" = "none";

      "terminal.integrated.fontSize" = 14;
      "terminal.integrated.fontFamily" = "'JetBrains Mono', monospace";

      "files.autoSave" = "afterDelay";
      "files.autoSaveDelay" = 1000;
      "files.trimTrailingWhitespace" = true;
      "files.insertFinalNewline" = true;

      # Git settings
      "git.enableSmartCommit" = true;
      "git.confirmSync" = false;
      "git.autofetch" = true;

      # Language-specific settings
      "python.defaultInterpreterPath" = "/usr/bin/python3";
      "nix.enableLanguageServer" = true;
      "nix.serverPath" = "nil";

      # Security
      "security.workspace.trust.untrustedFiles" = "open";
    };
  };
}
