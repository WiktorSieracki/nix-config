{self, ...}: {
  # The quickshell UI rides along with the niri feature exactly as noctalia
  # did before it (niri spawns it at startup and binds its IPC). The packages
  # go into the niri module so `quickshell-ui` and `quickshell-ui-ipc` resolve
  # via PATH (/run/current-system/sw/bin) — a stable name instead of a
  # per-generation store path. swaybg/swayidle/swaylock take over the
  # wallpaper/idle/lock duties noctalia used to own; niri.nix spawns them.
  flake.modules.nixos.niri = {pkgs, ...}: {
    environment.systemPackages = [
      self.packages.${pkgs.stdenv.hostPlatform.system}.quickshell-ui
      self.packages.${pkgs.stdenv.hostPlatform.system}.quickshell-ui-ipc
      pkgs.swaybg
      pkgs.swayidle
      pkgs.swaylock
    ];

    # swaylock authenticates through PAM; without this service entry it can
    # never accept the password and the session stays locked.
    security.pam.services.swaylock = {};
  };

  perSystem = {
    pkgs,
    lib,
    ...
  }: let
    # The QML config, as its own store path so the running process's `-p`
    # argument identifies the generation it came from.
    configDir = pkgs.runCommand "quickshell-ui-config" {} ''
      mkdir -p $out
      cp -r ${./shell}/. $out/
    '';
  in {
    packages.quickshell-ui = pkgs.writeShellApplication {
      name = "quickshell-ui";
      runtimeInputs = [pkgs.quickshell];
      text = ''
        exec qs -p ${configDir} "$@"
      '';
    };

    # quickshell matches a running instance by its `-p <config>` path, so an
    # IPC call against a different generation's config path prints "no
    # instances" and niri silently drops the bind — the same Mod+Space/Mod+P
    # drift noctalia-ipc existed to fix. This wrapper reads the -p path off
    # the running qs process and targets THAT path, so the pair can never
    # diverge; a baked store path to this script stays correct even when
    # stale, because the resolution happens at invocation time.
    packages.quickshell-ui-ipc = pkgs.writeShellApplication {
      name = "quickshell-ui-ipc";
      runtimeInputs = [pkgs.quickshell pkgs.procps pkgs.gnugrep];
      text = ''
        running=$(pgrep -af 'qs -p /nix/store/[^ ]*-quickshell-ui-config' \
          | grep -oE '/nix/store/[^ ]+-quickshell-ui-config' | head -n1) || true
        if [ -n "$running" ]; then
          exec qs -p "$running" ipc "$@"
        fi
        # No running instance found: fall back to this generation's config
        # (best effort, e.g. right after login).
        exec qs -p ${configDir} ipc "$@"
      '';
    };
  };
}
