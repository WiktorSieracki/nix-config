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

  # eduroam pulls its password/identity from SOPS (key supplied by the `sops`
  # feature) and only makes sense on the real eduroam network — runtimeUntestable.
  flake.featureMeta.eduroam = {
    requires = ["sops"];
    kind = "service";
    runtimeUntestable = true;
  };

  flake.featureTests.eduroam = {
    extraNixosModules = [
      ({lib, ...}: {
        # sops-nix can't render the profile's env without the real key, so the
        # NM profile can't materialise — and eduroam needs the real network +
        # RADIUS anyway (runtimeUntestable). Drop the secret-bound profile and
        # just prove the feature integrates and the system boots.
        sops.secrets = lib.mkForce {};
        sops.templates = lib.mkForce {};
        sops.age.sshKeyPaths = lib.mkForce [];
        # Override the SUB-options (not the parent attr) so the feature's own
        # definitions — incl. environmentFiles referencing the dropped template —
        # are discarded instead of still being evaluated.
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
