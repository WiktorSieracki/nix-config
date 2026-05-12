{
  flake.niriBinds.personal-snippets = {pkgs, ...}: {
    "Mod+Ctrl+N".spawn-sh = "${pkgs.wtype}/bin/wtype 'Wiktor Sieracki'";
    "Mod+Ctrl+E".spawn-sh = "${pkgs.wtype}/bin/wtype \"$(cat /run/secrets/personalEmail)\"";
    "Mod+Ctrl+G".spawn-sh = "${pkgs.wtype}/bin/wtype 'https://github.com/WiktorSieracki'";
    "Mod+Ctrl+I".spawn-sh = "${pkgs.wtype}/bin/wtype 'https://www.linkedin.com/in/wiktor-sieracki-b54817272/'";
  };
}
