{
  flake.modules.nixos.niri = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      (writeShellScriptBin "form-at" (
        builtins.readFile ./form-at.sh
      ))
    ];
  };
}
