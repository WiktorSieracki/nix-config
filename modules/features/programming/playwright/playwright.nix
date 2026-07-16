{...}: {
  flake.modules = {
    homeManager.playwright = {pkgs, ...}: let
      browsers = pkgs.playwright-driver.browsers;
    in {
      # playwright-test = the `playwright` CLI with the @playwright/test runner
      # baked in (`playwright test`, `screenshot`, `codegen`, ...). Playwright
      # normally downloads its own browser builds, which don't run on NixOS —
      # the wrapper bakes in the nix-built browsers so the CLI works from any
      # context (shell, IDE, CI), not only HM-managed login shells.
      home.packages = [
        (pkgs.symlinkJoin {
          name = "playwright-test-nixos";
          paths = [pkgs.playwright-test];
          nativeBuildInputs = [pkgs.makeWrapper];
          postBuild = ''
            wrapProgram $out/bin/playwright \
              --set-default PLAYWRIGHT_BROWSERS_PATH ${browsers} \
              --set-default PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS true
          '';
        })
      ];

      # For npm-installed playwright inside projects (npx playwright ...): the
      # env vars must be in the interactive session, not just the nix wrapper.
      # Its @playwright/test version must match nixpkgs' (see notes.md).
      home.sessionVariables = {
        PLAYWRIGHT_BROWSERS_PATH = "${browsers}";
        PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS = "true";
      };
    };
  };

  flake.featureMeta.playwright = {
    requires = [];
    kind = "cli";
  };

  flake.featureTests.playwright = {
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("home-manager-tester.service")
      machine.succeed("su - tester -c 'command -v playwright'")
      machine.succeed("su - tester -c 'playwright --version'")
      # session vars (for npm playwright) must point at the nix-built browsers;
      # the minimal VM has no HM-managed shell, so source hm-session-vars directly
      machine.succeed(
          "su - tester -c '. /etc/profiles/per-user/tester/etc/profile.d/hm-session-vars.sh; echo $PLAYWRIGHT_BROWSERS_PATH' | grep -q /nix/store"
      )
      # real smoke: drive headless chromium against a local page
      machine.succeed("echo '<html><body><h1>tester</h1></body></html>' > /tmp/tester.html")
      machine.succeed("su - tester -c 'playwright screenshot --browser chromium file:///tmp/tester.html /tmp/tester.png'")
      machine.succeed("test -s /tmp/tester.png")
    '';
  };
}
