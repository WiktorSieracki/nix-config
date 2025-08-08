{ config, pkgs, ... }:

{
  services.fprintd.enable = true;

  environment.systemPackages = with pkgs; [
    fprintd
    libfprint
    # For testing or GUI enrollment
    gnome.gnome-control-center
    gnome.gnome-settings-daemon

    # Optional tools
    wget
    patchelf

    # Allow FHS user environment for running Ubuntu binaries
    (buildFHSUserEnv {
      name = "fingerprint-env";
      targetPkgs = pkgs: with pkgs; [
        glibc
        openssl_1_1
        systemd
        udev
        dbus
        pam
        # add others as needed
      ];
      runScript = "bash";
    })
  ];

  programs.dconf.enable = true;
}