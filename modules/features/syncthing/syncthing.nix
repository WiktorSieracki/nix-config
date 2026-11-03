let
  # Who syncs what is personal, like ssh-personal-hosts: device IDs of concrete
  # machines and a concrete vault. Each ID is derived from the key in
  # ~/.local/state/syncthing on that machine (notes.md).
  devices = {
    desktop = {
      id = "APNNLQE-PU3DHIJ-EWAXXK6-7BPIALG-4U44H7X-FTLKYDY-LTA7X36-ES5ONQW";
      addresses = ["tcp://desktopnixos:22000"];
    };
    vps = {
      id = "YFQIJYC-ZQ7OC4S-KWI2LD6-SG4RK4Y-3JEZDH5-5G4A2A7-CNKPILF-YH2VUAO";
      addresses = ["tcp://vps-nixos:22000"];
    };
  };
in {
  flake.modules.nixos.syncthing = {
    lib,
    hostUsers ? {},
    ...
  }: {
    # The service runs under the user manager, which on a headless host only
    # exists between login and logout without lingering.
    users.users =
      lib.genAttrs
      (lib.filter (u: builtins.elem "syncthing" hostUsers.${u}) (builtins.attrNames hostUsers))
      (_: {linger = true;});

    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [22000];
  };

  flake.modules.homeManager.syncthing = {config, ...}: {
    services.syncthing = {
      enable = true;
      settings = {
        # Peers find each other only through the fixed tailnet addresses above.
        options = {
          listenAddresses = ["tcp://:22000"];
          globalAnnounceEnabled = false;
          localAnnounceEnabled = false;
          relaysEnabled = false;
          natEnabled = false;
          urAccepted = -1;
          crashReportingEnabled = false;
        };
        inherit devices;
        folders.second-brain = {
          label = "Second Brain";
          path = "${config.home.homeDirectory}/Projects/second-brain";
          devices = builtins.attrNames devices;
          # The vault has no git history, so this is what makes a deletion on
          # one machine recoverable on the other.
          versioning = {
            type = "simple";
            params.keep = "10";
          };
          ignorePatterns = [
            # A .git synced file by file corrupts when both sides write to it.
            ".git"
            ".trash"
            # Same volatile Obsidian state the vault's .gitignore lists.
            ".obsidian/workspace.json"
            ".obsidian/workspace-mobile.json"
            # graphify's cache and the paths it pins to this machine's install.
            "/graphify-out/cache"
            "/graphify-out/.graphify_python"
            "/graphify-out/.graphify_root"
          ];
        };
      };
    };
  };

  flake.featureMeta.syncthing = {
    requires = ["tailscale"];
    kind = "service";
    # The feature's own units are user units, which `provides.units` can't name;
    # the feature test waits on those. tailscaled is what its peers depend on.
    provides = {
      units = ["tailscaled.service"];
      ports = [8384 22000];
    };
  };

  # feature test: assert what Syncthing itself reports over its REST API, since
  # the settings are applied at runtime by syncthing-init, not read from a file.
  flake.featureTests.syncthing = {
    extraNixosModules = [({pkgs, ...}: {environment.systemPackages = [pkgs.curl];})];
    testScript = ''
      import json

      machine.wait_for_unit("syncthing.service", "tester")
      machine.wait_for_unit("syncthing-init.service", "tester")
      key = machine.succeed(
          "grep -oP '(?<=<apikey>)[^<]+' /home/tester/.local/state/syncthing/config.xml"
      ).strip()

      def api(path):
          return json.loads(machine.succeed(
              f"curl -sf -H 'X-API-Key: {key}' http://127.0.0.1:8384/rest{path}"
          ))

      # Peers are reached only over the tailnet; anything that would announce
      # this machine or route through a third party has to stay off.
      options = api("/config/options")
      for name in ["globalAnnounceEnabled", "localAnnounceEnabled", "relaysEnabled", "natEnabled"]:
          assert options[name] is False, f"{name} is on: {options[name]}"
      assert options["urAccepted"] < 0, f"telemetry not refused: {options['urAccepted']}"

      devices = {d["name"]: d["addresses"] for d in api("/config/devices")}
      assert devices["vps"] == ["tcp://vps-nixos:22000"], devices
      assert devices["desktop"] == ["tcp://desktopnixos:22000"], devices

      folder = api("/config/folders/second-brain")
      assert folder["path"] == "/home/tester/Projects/second-brain", folder["path"]
      # The vault has no git history, so a deletion must stay recoverable.
      assert folder["versioning"]["type"] == "simple", folder["versioning"]

      # A .git synced file by file corrupts when both sides write to it.
      ignores = api("/db/ignores?folder=second-brain")["ignore"]
      assert ".git" in ignores, ignores
    '';
  };
}
