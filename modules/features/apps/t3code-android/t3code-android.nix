_: let
  # T3 Code's Device panel reports Android as available only when one SDK root
  # holds `platform-tools/adb`, `emulator/emulator` and
  # `cmdline-tools/latest/bin/avdmanager`, even for a physical phone, which then
  # only ever uses adb. androidenv names the last one after its version, so this
  # layer adds the `latest` alias. nixpkgs' own `android-tools` is no substitute:
  # its adb is built without mDNS, which is how a paired phone is found again
  # after wireless debugging picks a new port. See notes.md.
  androidSdkFor = pkgs: let
    sdk =
      ((pkgs.androidenv.override {licenseAccepted = true;}).composeAndroidPackages {
        includeEmulator = true;
        toolsVersion = null;
        platformVersions = [];
        buildToolsVersions = [];
      }).androidsdk;
  in
    pkgs.runCommand "t3code-android-sdk" {} ''
      root=${sdk}/libexec/android-sdk
      mkdir -p $out/bin $out/cmdline-tools
      ln -s $root/platform-tools $out/platform-tools
      ln -s $root/emulator $out/emulator
      ln -s $root/cmdline-tools/* $out/cmdline-tools/latest
      ln -s $root/platform-tools/adb $out/bin/adb
    '';
in {
  flake.modules = {
    nixos.t3code-android = {
      # adb's mDNS client listens on this port itself. Replies come back from the
      # phone's address, not the multicast group, so the firewall's connection
      # tracking does not recognise them and drops every one (measured 2026-11-03).
      networking.firewall.allowedUDPPorts = [5353];
    };

    homeManager.t3code-android = {pkgs, ...}: let
      sdk = androidSdkFor pkgs;
    in {
      home.packages = [sdk];
      # The backend reads the SDK root when it starts and hands it to the device
      # hub. It is the app's backend, a transient service of the user manager,
      # so it can only inherit the root from the manager's environment, which
      # environment.d sets when the manager starts: a new root takes effect at
      # the next login (notes.md).
      systemd.user.sessionVariables.ANDROID_HOME = "${sdk}";
    };
  };

  flake.featureMeta.t3code-android = {
    # The Device panel lives in the app and the devices on its host: a phone
    # plugs into the machine you sit at.
    requires = ["t3code"];
    kind = "cli";
    # The check that matters needs a real phone on the LAN. The feature test
    # guards the SDK layout T3 Code insists on and adb's mDNS support.
    runtimeUntestable = true;
    provides.userBins = ["adb"];
  };

  flake.featureTests.t3code-android = {
    testScript = ''
      env = "/home/tester/.config/environment.d/10-home-manager.conf"
      sdk = machine.succeed(f"grep -oP '^ANDROID_HOME=\\K\\S+' {env}").strip()

      # The three paths LocalDeviceHost.ts checks before it offers Android.
      for tool in ["platform-tools/adb", "emulator/emulator", "cmdline-tools/latest/bin/avdmanager"]:
          machine.succeed(f"test -x {sdk}/{tool}")

      # avdmanager runs on the JDK androidenv wraps it with; the hub lists
      # devices through it.
      machine.succeed(f"ANDROID_HOME={sdk} {sdk}/cmdline-tools/latest/bin/avdmanager list avd")

      # nixpkgs' android-tools answers "mdns is not supported by this version".
      machine.succeed(f"su tester -c 'HOME=/tmp {sdk}/platform-tools/adb start-server'")
      output = machine.succeed(f"su tester -c 'HOME=/tmp {sdk}/platform-tools/adb mdns check' 2>&1")
      assert "not supported" not in output, output

      machine.succeed("iptables -S nixos-fw | grep -q 'udp.*--dport 5353'")
    '';
  };
}
