{config, ...}: {
  sops.defaultSopsFile = ../../secrets.yaml;
  sops.age.sshKeyPaths = ["/home/wiktor/.ssh/id_ed25519"];
  sops.secrets.eduroamPassword = {};

  networking.networkmanager.ensureProfiles.environmentFiles = [
    config.sops.secrets.eduroamPassword.path
  ];

  networking.networkmanager.ensureProfiles.profiles = {
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
        identity = "w.sieracki.643@studms.ug.edu.pl";
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
}
