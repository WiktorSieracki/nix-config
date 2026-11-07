{
  # Print and scan without hunting for drivers. Nearly every network printer
  # and multifunction device sold in the last decade speaks IPP Everywhere
  # (printing) and eSCL/WSD (scanning), so the stack here is driverless:
  # CUPS creates a temporary queue for any printer avahi finds on the LAN, and
  # sane-airscan lets simple-scan see network scanners.
  flake.modules.nixos.printing = {pkgs, ...}: {
    services.printing = {
      enable = true;
      # cups-browsed is not needed for driverless printers (CUPS' own DNS-SD
      # handles temporary queues), and it was the remote-code-execution entry
      # point of CVE-2024-47176. NixOS turns it on together with avahi.
      browsed.enable = false;
    };

    # mDNS: printer discovery and `*.local` name resolution.
    services.avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };

    hardware.sane = {
      enable = true;
      extraBackends = [pkgs.sane-airscan];
    };

    environment.systemPackages = [pkgs.simple-scan];
  };

  flake.featureMeta.printing = {
    kind = "service";
    provides = {
      units = ["cups.socket" "avahi-daemon.service"];
      ports = [631];
      systemBins = ["lp" "lpstat" "lpinfo" "scanimage" "simple-scan"];
    };
  };

  # feature test: a real driverless print, end to end. CUPS' own
  # `ippeveprinter` plays an IPP Everywhere printer; `lpadmin -m everywhere`
  # builds the queue the driverless way (CUPS asks the printer for its
  # attributes over IPP and generates the driver itself, no vendor PPD), a job
  # goes through it, and the test checks it landed in the printer's spool.
  #
  # mDNS discovery can't be shown end to end: ippeveprinter aborts inside
  # avahi-client when it registers itself (notes.md), so it runs with DNS-SD
  # off and the discovery side is covered by avahi-daemon running (provides)
  # plus mdns in the resolver. Scanning has no fake device; the test asserts
  # SANE loads the airscan backend.
  flake.featureTests.printing = {
    testScript = ''
      machine.succeed("lpstat -r | grep -q 'scheduler is running'")
      machine.succeed("grep -E '^hosts:.*mdns4_minimal' /etc/nsswitch.conf")
      machine.fail("systemctl cat cups-browsed.service")

      machine.succeed("mkdir -p /tmp/ippspool")
      machine.succeed(
          "systemd-run --unit fake-printer ippeveprinter -r off -n localhost -k"
          " -d /tmp/ippspool -p 8631 -f application/pdf,text/plain FakePrinter"
      )
      machine.wait_for_open_port(8631)
      machine.succeed("lpadmin -p fake -E -v ipp://localhost:8631/ipp/print -m everywhere")
      machine.succeed("echo 'hello from the printing feature test' | lp -d fake")
      machine.wait_until_succeeds("lpstat -W completed -o fake | grep -q fake-", timeout=60)
      machine.wait_until_succeeds("test -n \"$(ls -A /tmp/ippspool)\"", timeout=30)

      # SANE_DEBUG_DLL prints every backend dll.conf asks it to load.
      machine.succeed("SANE_DEBUG_DLL=3 scanimage -L 2>&1 | grep -q 'airscan'")
    '';
  };
}
