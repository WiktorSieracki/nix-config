{config, ...}: {
  imports = [
    # ../shared.nix
    ../../modules/vscode.nix
    ../../modules/niri
  ];
}
