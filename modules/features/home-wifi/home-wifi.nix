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

  # home-wifi pulls its PSK from SOPS (key supplied by the `sops` feature) and
  # only connects to the real home AP — runtimeUntestable in a VM.
  flake.featureMeta.home-wifi = {
    requires = ["sops"];
    kind = "service";
    runtimeUntestable = true;
  };

  flake.featureTests.home-wifi = {
    extraNixosModules = [
      ({lib, ...}: {
        # Same as eduroam: no SOPS key → no rendered env → no NM profile, and the
        # feature needs the real AP anyway (runtimeUntestable). Drop the profile,
        # prove integration + boot.
        sops.secrets = lib.mkForce {};
        sops.templates = lib.mkForce {};
        sops.age.sshKeyPaths = lib.mkForce [];
        networking.networkmanager.ensureProfiles.environmentFiles = lib.mkForce [];
        networking.networkmanager.ensureProfiles.profiles = lib.mkForce {};
      })
    ];
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("command -v nmcli")
    '';
  };
}
