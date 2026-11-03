let
  # Built from arguments so the feature test can run it against stub data: a VM
  # has neither the nix-index database nor a nixpkgs to search.
  mkCommandNotFound = {
    pkgs,
    nix,
    nixIndex,
  }:
    pkgs.writeShellApplication {
      name = "fish-command-not-found";
      runtimeInputs = [
        nix
        nixIndex
        pkgs.coreutils
        pkgs.gawk
        pkgs.gnugrep
        pkgs.gnused
        pkgs.jq
        pkgs.util-linux
      ];
      text = builtins.readFile ./command-not-found.sh;
    };
in {
  flake.modules = {
    nixos.fish = {
      config,
      pkgs,
      ...
    }: {
      programs.fish.enable = true;

      # The package (with its prebuilt database) comes from the `nix` feature's
      # nix-index-database module where that is enabled.
      programs.nix-index = {
        enable = true;
        # Replaced below: upstream's hook prints nothing useful for a command no
        # package ships verbatim, and suggests `nix-env -iA`.
        enableFishIntegration = false;
      };
      programs.fish.interactiveShellInit = let
        commandNotFound = mkCommandNotFound {
          inherit pkgs;
          nix = config.nix.package;
          nixIndex = config.programs.nix-index.package;
        };
      in ''
        function fish_command_not_found
            ${commandNotFound}/bin/fish-command-not-found $argv
        end
      '';

      # NOTE: the login shell is NOT set here. Which account uses fish as its
      # shell is identity data — it lives in flake.meta.users.<login>.shell and
      # the host loader (mkHostUser) applies it. This module only provides fish.
    };

    homeManager.fish = {
      pkgs,
      lib,
      ...
    }: {
      # fish-ssh-agent (below) starts the agent by redirecting into $SSH_ENV,
      # which defaults to ~/.ssh/environment, then chmod-ing and sourcing it.
      # On a home that has never had an ssh key -- the installer ISO, a fresh
      # install, any new user -- ~/.ssh does not exist, so all three steps fail
      # and every single login opens with four lines of error. Create the
      # directory so the plugin has somewhere to write.
      home.activation.ensureSshDir = lib.hm.dag.entryAfter ["writeBoundary"] ''
        run mkdir -p -m 700 "$HOME/.ssh"
      '';

      programs = {
        direnv = {
          enable = true;
          enableFishIntegration = true;
          nix-direnv.enable = true;
        };
      };

      programs.fish = {
        enable = true;

        shellAliases = {
          npx = "pnpx";
          npm = "pnpm";
          nnpm = "npm";
          nnpx = "npx";
        };

        plugins = [
          {
            name = "z";
            src = pkgs.fishPlugins.z.src;
          }
          {
            name = "fish-ssh-agent";
            src = pkgs.fetchFromGitHub {
              owner = "danhper";
              repo = "fish-ssh-agent";
              rev = "f10d95775352931796fd17f54e6bf2f910163d1b";
              sha256 = "cFroQ7PSBZ5BhXzZEKTKHnEAuEu8W9rFrGZAb8vTgIE=";
            };
          }
        ];
      };
    };
  };

  # Fish shell: system-level programs.fish.enable + a nix-index/nix-search
  # command-not-found handler,
  # HM direnv + plugins. Login-shell assignment lives in flake.meta.users.
  flake.featureMeta.fish = {
    requires = [];
    kind = "config";
    provides = {
      systemBins = ["fish"];
      userBins = ["direnv"];
    };
  };

  # feature test: shell *assignment* is the loader's job — asserted by the
  # host-users mechanism check, not here. `provides` covers the rest.
  flake.featureTests.fish = {
    extraNixosModules = [
      ({pkgs, ...}: let
        stubLocate = pkgs.writeShellScriptBin "nix-locate" ''
          case "$*" in
            */bin/exactcmd*) printf '%s\n' tests.exactcmd.out neo-exactcmd.out exactcmd.out ;;
          esac
        '';
        stubNix = pkgs.writeShellScriptBin "nix" ''
          case "$*" in
            *coldcmd*) exec sleep 60 ;;
            *hetzner*) cat <<'JSON'
          {
            "legacyPackages.x86_64-linux.fakecloud": {"description": "CLI for Hetzner Cloud", "pname": "fakecloud", "version": "1"},
            "legacyPackages.x86_64-linux.lazyhetzner": {"description": "TUI", "pname": "lazyhetzner", "version": "1"},
            "legacyPackages.x86_64-linux.python3Packages.hetzner": {"description": "duplicate", "pname": "hetzner", "version": "1"}
          }
          JSON
              ;;
            *) echo '{}' ;;
          esac
        '';
      in {
        # The real wiring (fish -> handler) gets the stub nix-locate...
        programs.nix-index.package = stubLocate;
        # ...and the search branch, which needs a stub nix, runs directly.
        environment.systemPackages = [
          (pkgs.writeShellScriptBin "fakecloud" "")
          (mkCommandNotFound {
            inherit pkgs;
            nix = stubNix;
            nixIndex = stubLocate;
          })
        ];
      })
    ];
    testScript = ''
      def in_tty(command):
          return machine.succeed(f"script -qc '{command}' /dev/null 2>&1 || true")

      # Exact match, through fish itself: shortest top-level attr first, no
      # sub-attrs, no `nix-env -iA`.
      out = machine.succeed("su - tester -c \"script -qc 'fish -ic exactcmd' /dev/null\" 2>&1 || true")
      assert "exactcmd: command not found" in out, out
      assert "nix shell nixpkgs#exactcmd -c exactcmd" in out, out
      assert out.index("nixpkgs#exactcmd") < out.index("nixpkgs#neo-exactcmd"), out
      assert "tests.exactcmd" not in out and "nix-env" not in out, out

      # Description search: the installed command leads, duplicates are dropped.
      out = in_tty("fish-command-not-found hetzner")
      assert "Installed, did you mean:" in out, out
      assert "fakecloud" in out and "nix shell nixpkgs#lazyhetzner" in out, out
      assert out.index("fakecloud") < out.index("lazyhetzner"), out
      assert "python3Packages" not in out, out

      # No match anywhere: nothing but the plain message.
      out = in_tty("fish-command-not-found nosuchcmdzz")
      assert out.strip() == "nosuchcmdzz: command not found", out

      # Cold cache on a small machine: the eval is killed, not left to OOM it.
      out = in_tty("fish-command-not-found coldcmd")
      assert "nix search nixpkgs coldcmd" in out, out
      machine.fail("pgrep -f 'sleep 60'")

      # Outside a terminal (pipes, scripts): plain message, instantly.
      status, out = machine.execute("fish-command-not-found exactcmd 2>&1 | cat")
      assert status == 127 and out.strip() == "exactcmd: command not found", (status, out)
    '';
  };
}
