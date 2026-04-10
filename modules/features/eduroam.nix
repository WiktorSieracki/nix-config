{inputs, ...}: {
  flake.modules.nixos.eduroam = {config, ...}: {
    imports = [
      inputs.sops-nix.nixosModules.sops
    ];

    sops.secrets.eduroamPassword = {};
    sops.secrets.studentEmail = {};

    sops.templates."eduroam-env".content = ''
      EDUROAM_IDENTITY=${config.sops.placeholder.studentEmail}
      EDUROAM_PASSWORD=${config.sops.placeholder.eduroamPassword}
    '';

    networking.networkmanager.ensureProfiles = {
      environmentFiles = [config.sops.templates."eduroam-env".path];
      profiles.eduroam = {
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
