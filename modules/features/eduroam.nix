{config, ...}: {
  flake.modules.nixos.eduroam = {pkgs, ...}: {
    sops.secrets.eduroamPassword = {};
    sops.secrets.studentEmail = {};

    sops.templates."eduroam-env".content = ''
      EDUROAM_IDENTITY=${config.sops.placeholder.studentEmail}
      EDUROAM_PASSWORD=${config.sops.placeholder.eduroamPassword}
    '';

    networking.networkmanager.ensureProfiles.profiles = {
      environmentFiles = [config.sops.templates."eduroam-env".path];
      eduroam = {
        connection = {
          id = "eduroam";
          type = "wifi";
          interface-name = "wlp3s0";
        };
        wifi = {
          mode = "infrastructure";
          ssid = "eduroam";
        };
        wifi-security = {
          key-mgmt = "wpa-eap";
        };
        "802-1x" = {
          eap = "peap";
          phase2-auth = "mschapv2";
          anonymous-identity = "anonymous@studms.ug.edu.pl";
          identity = "$EDUROAM_IDENTITY";
          password = "$EDUROAM_PASSWORD";
        };
        ipv4 = {
          method = "auto";
        };
        ipv6 = {
          method = "auto";
        };
      };
    };
  };
}
