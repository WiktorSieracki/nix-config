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
          # No `interface-name`: the card is called wlp13s0 on the desktop and
          # wlp3s0 on the laptop, and a profile bound to one name never
          # activates on the other machine.
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
    provides.systemBins = ["nmcli"];
  };

  # feature test: the real AP is out of reach, but the profile itself is not —
  # with a stand-in for the SOPS env file, NetworkManager renders and loads it
  # in the VM. That pins what a host actually depends on: the profile exists,
  # carries the PSK from the env file, and is tied to no particular wifi card.
  flake.featureTests.home-wifi = {
    extraNixosModules = [
      ({
        lib,
        pkgs,
        ...
      }: {
        sops.secrets = lib.mkForce {};
        sops.templates = lib.mkForce {};
        sops.age.sshKeyPaths = lib.mkForce [];
        networking.networkmanager.ensureProfiles.environmentFiles = lib.mkForce [
          (pkgs.writeText "home-wifi-env" "HOME_WIFI_PASSWORD=stand-in-psk-for-the-test\n")
        ];
      })
    ];
    testScript = ''
      profile = "PLAY_Swiatlowodowy_4337_5G"
      # NetworkManager-ensure-profiles is a oneshot that exits as soon as the
      # profile is written, so wait on what it produces, not on the unit.
      machine.wait_until_succeeds(
          f"nmcli -g connection.type connection show {profile} | grep -qx 802-11-wireless",
          timeout=60,
      )
      machine.succeed(f"nmcli -s -g 802-11-wireless-security.psk connection show {profile} | grep -qx stand-in-psk-for-the-test")
      # Bound to one interface name, the profile only ever activates on the
      # machine that has a card by that name — it carried the desktop's
      # (wlp13s0), so the laptop never joined the home network with it.
      bound = machine.succeed(f"nmcli -g connection.interface-name connection show {profile}").strip()
      assert bound == "", f"home-wifi profile is bound to interface {bound!r}; it must work on any host's wifi card"
    '';
  };
}
