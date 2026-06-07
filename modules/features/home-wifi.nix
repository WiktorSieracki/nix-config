{inputs, ...}: {
  flake.modules.nixos.home-wifi = {config, ...}: {
    imports = [
      inputs.sops-nix.nixosModules.sops
    ];

    sops.secrets.homeWifiPassword = {};

    sops.templates."home-wifi-env".content = ''
      HOME_WIFI_PASSWORD=${config.sops.placeholder.homeWifiPassword}
    '';

    networking.networkmanager.ensureProfiles = {
      environmentFiles = [config.sops.templates."home-wifi-env".path];
      profiles.home-wifi = {
        connection = {
          id = "PLAY_Swiatlowodowy_4337_5G";
          type = "wifi";
          interface-name = "wlp13s0";
        };
        wifi = {
          mode = "infrastructure";
          ssid = "PLAY_Swiatlowodowy_4337_5G";
        };
        wifi-security = {
          key-mgmt = "wpa-psk";
          psk = "$HOME_WIFI_PASSWORD";
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
