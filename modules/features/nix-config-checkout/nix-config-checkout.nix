{config, ...}: let
  repo = config.flake.meta.repo;
in {
  # Gives an account the checkout its own `NH_FLAKE` points at.
  #
  # A fresh account on an existing machine has no ~/.config/nix-config, so
  # `nh os switch` fails before it does anything. A from-scratch install gets
  # the checkout from `nixos-bootstrap`; this covers every other way an account
  # comes into being (a new login added to a host's features.json, a home
  # restored without it, a machine installed by hand).
  flake.modules.homeManager.nix-config-checkout = {
    pkgs,
    lib,
    ...
  }: let
    checkout = pkgs.writeShellApplication {
      name = "nix-config-checkout";
      runtimeInputs = [pkgs.git];
      text =
        builtins.replaceStrings
        ["@httpsUrl@" "@sshUrl@"]
        [repo.https repo.ssh]
        (builtins.readFile ./checkout.sh);
    };
  in {
    # Also on PATH, so the same code path can be run by hand after a failed
    # boot-time attempt instead of being re-derived in a shell.
    home.packages = [checkout];

    systemd.user.services.nix-config-checkout = {
      Unit = {
        Description = "Clone the nix-config repository into this account";
        Wants = ["network-online.target"];
        After = ["network-online.target"];
      };

      Service = {
        Type = "oneshot";
        # The work is idempotent and the result is a directory, not a process;
        # RemainAfterExit keeps `systemctl --user status` meaningful afterwards.
        RemainAfterExit = true;
        ExecStart = lib.getExe checkout;
      };

      Install.WantedBy = ["default.target"];
    };
  };

  flake.featureMeta.nix-config-checkout = {
    requires = [];
    # `cli`, not `service`: the unit is a user unit, and the harness's `units`
    # assertion waits on *system* units. What can be declared is the binary and
    # the generated unit file; the behaviour is asserted in the test script.
    kind = "cli";
    provides = {
      userBins = ["nix-config-checkout"];
      userFiles = [".config/systemd/user/nix-config-checkout.service"];
    };
  };

  # feature test: the two properties that matter are both reachable offline —
  # which is the point. A nixosTest VM has no network, so the clone path is
  # exercised in exactly the failure mode the script must survive.
  flake.featureTests.nix-config-checkout = {
    testScript = ''
      # An existing checkout is never touched — the sentinel must survive.
      machine.succeed("su - tester -c 'mkdir -p ~/.config/nix-config'")
      machine.succeed("su - tester -c 'touch ~/.config/nix-config/SENTINEL'")
      machine.succeed("su - tester -c 'nix-config-checkout'")
      machine.succeed("su - tester -c 'test -e ~/.config/nix-config/SENTINEL'")

      # With no network the clone cannot succeed; the script must still exit 0
      # (a failing user unit is what this design exists to avoid) and must not
      # leave a half-made directory behind.
      machine.succeed("su - tester -c 'rm -rf ~/.config/nix-config'")
      machine.succeed("su - tester -c 'nix-config-checkout'")
      machine.succeed("su - tester -c 'test ! -e ~/.config/nix-config'")
    '';
  };
}
