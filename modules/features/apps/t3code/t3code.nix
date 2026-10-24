{inputs, ...}: let
  # nixpkgs ships the whole of upstream in one derivation: `bin/t3` (the Node
  # server + CLI) and `bin/t3code-desktop` (the Electron client). Each feature
  # takes one half — `t3CliFor` for the server, `t3codeAppFor` for the client —
  # and neither takes the package as-is.
  #
  # nixpkgs wraps every t3code binary with a PATH prefix of the agents it should
  # drive. We swap nixpkgs' claude-code for the llm-agents one so t3code runs the
  # exact same `claude` the `claude-code` feature puts on PATH, and drop codex
  # (nixpkgs enables it by default) — no account here is logged into it. t3code
  # finds a provider by binary name, so `claude` on PATH is the whole contract;
  # see notes.md.
  # Every provider t3code spawns inherits this process's environment, and the
  # Antigravity ACP server (`agy_acp_server.par`) is a foreign, non-patched
  # binary carrying its own embedded Python. That Python's OpenSSL looks for a
  # trust store where NixOS has none, so *every* model call died in
  # `ccpa_client.stream_generate_content` with CERTIFICATE_VERIFY_FAILED — which
  # its in-process proxy then reported to the agent as `502 Bad Gateway: Failed
  # to connect to backend API`, a message that reads exactly like an upstream
  # outage. Measured 2026-09-18: same binary, same token, the variable alone
  # flips the turn from that 502 to a real answer. `/etc/ssl/certs` (not a
  # `pkgs.cacert` store path) so the system trust store — including anything
  # `security.pki` adds — is what the provider sees. See notes.md.
  caBundle = "/etc/ssl/certs/ca-certificates.crt";

  # nixpkgs trails upstream's stable tags, so the version is pinned here: only
  # `src` and the pnpm dependency hash change, the rest of nixpkgs' recipe is
  # reused as-is. The resource-monitor sidecar inherits `src` from this
  # derivation and keeps nixpkgs' `cargoHash`, which stays valid only while
  # `native/resource-monitor/Cargo.lock` is unchanged. Drop the pin once
  # nixpkgs catches up (notes.md, "Updating").
  version = "0.1.0";
  srcHash = "sha256-P82DqoY1E9wtROwu5Nr7MB/I1PdmZHWXXR4nRa4GWXM=";
  pnpmDepsHash = "sha256-oX4tOu20tYO3ci7VvSEL8eFgxAYWp5HlQFSfAWJGJmg=";

  # Electron on Linux keeps the app's safeStorage key in the keyring under the
  # `productName` of the app's package.json, and upstream renames it with every
  # release stage ("T3 Code (Alpha)" → "T3 Code (Beta)" in 0.1.0). After a
  # rename the app mints a fresh key, can no longer decrypt
  # `connection-catalog.json`, and the paired unit silently drops out of
  # Settings → Connections (measured 2026-10-16, notes.md). Pinning the name
  # pins the key. It stays at the name the existing key was created under.
  keyringName = "T3 Code (Alpha)";

  # JPEG quality of the server browser's preview stream, at rest and while
  # scrolling (upstream: 70 / 50). See `postPatch` in `t3codeUnwrappedFor`.
  streamQuality = 92;
  streamMotionQuality = 75;

  # The server browser's display. `server-browser-headed.patch` swaps the
  # downloaded `chrome-headless-shell` for a full Google Chrome, run headed:
  # Google rejects the shell's sign-in (`/v3/signin/rejected`) but lets the full
  # browser through to the password step (measured 2026-10-24, notes.md). A
  # headed browser needs an X display, and the unit must not put windows on the
  # niri session, so it gets a virtual one of its own.
  browserDisplayNumber = "99";
  browserDisplay = ":${browserDisplayNumber}";
  # Bitwarden, force-installed into that Chrome by policy (notes.md).
  bitwardenExtensionId = "nngceckbapebfimnlniiiahkandclblb";

  # Since 0.0.44 node-pty (1.2.0-beta) ships a linux-x64 prebuild, so the
  # package's `pnpm rebuild` no longer compiles `pty.node` from source — and with
  # `dontPatchELF` nothing points the prebuilt at a libstdc++. nodejs links one
  # anyway, but the app's backend runs under Electron, which does not: it died
  # with NodePtyModuleLoadError and the app never opened a window (2026-10-08).
  # Only this one file gets the rpath; the rest of the vendored tree stays
  # untouched, as upstream intends. Drop this once nixpkgs patches it.
  # The same hook pins the app's productName; see `keyringName`.
  t3codeUnwrappedFor = pkgs:
    pkgs.t3code.unwrapped.overrideAttrs (finalAttrs: old: {
      inherit version;
      src = old.src.override {
        tag = "v${version}";
        hash = srcHash;
      };
      pnpmDeps = pkgs.fetchPnpmDeps {
        inherit (finalAttrs) pname version src pnpmWorkspaces;
        pnpm = pkgs.pnpm_11;
        fetcherVersion = 4;
        hash = pnpmDepsHash;
      };
      # Runs `T3CODE_SERVER_BROWSER_EXECUTABLE`, when set, headed in place of
      # the headless shell, with extensions and sync left on. See `browserDisplay`.
      #
      # The app reaches the unit as a saved environment, which upstream always
      # treats as another machine: "Open in VS Code" became an SSH deep link
      # into this very host. On loopback the app now opens the local editor's
      # `vscode://file/<path>` link instead (notes.md).
      patches =
        (old.patches or [])
        ++ [
          ./server-browser-headed.patch
          ./open-local-editor.patch
        ];
      nativeBuildInputs = old.nativeBuildInputs ++ [pkgs.patchelf pkgs.jq];
      # The server's browser streams every tab it hosts (all agent tabs) to the
      # client as JPEG frames. The client never asks for a quality, so the
      # server's default of 70 — 50 while scrolling — is what you see: soft text
      # and ringing around edges (upstream #16578, closed without a setting).
      # Recordings already use 90. Raise both; the stream runs over loopback or
      # the tailnet, where the extra bytes don't matter. See notes.md.
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace apps/server/src/preview/ServerBrowserStream.ts \
            --replace-fail 'const DEFAULT_QUALITY = 70;' 'const DEFAULT_QUALITY = ${toString streamQuality};'
          substituteInPlace apps/server/src/preview/ServerBrowser.ts \
            --replace-fail 'const SCREENCAST_MOTION_QUALITY = 50;' 'const SCREENCAST_MOTION_QUALITY = ${toString streamMotionQuality};'
        '';
      postFixup =
        (old.postFixup or "")
        + ''
          find "$out"/libexec/t3code -path '*/node-pty/prebuilds/linux-*/pty.node' \
            -exec patchelf --add-rpath ${pkgs.lib.getLib pkgs.stdenv.cc.cc}/lib {} +

          pj="$out"/libexec/t3code/apps/desktop/package.json
          jq --arg name ${pkgs.lib.escapeShellArg keyringName} '.productName = $name' "$pj" > "$pj.tmp"
          mv "$pj.tmp" "$pj"
        '';
    });

  t3codeFor = pkgs:
    pkgs.t3code.override {
      t3code-unwrapped = t3codeUnwrappedFor pkgs;
      enableClaude = true;
      claude-code = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code;
      enableCodex = false;
    };

  # `t3` on its own. Upstream's own desktop entry is the trap: it runs
  # `t3code-desktop` bare, and a bare app forks a second backend onto the unit's
  # own `~/.t3` database, where the two servers' projections drift (notes.md).
  # Dropping `share/applications` is what keeps that entry out of the launcher,
  # leaving `t3codeAppFor`'s wrapper — which isolates the app's backend — as the
  # only way in. Everything else the package ships (icons, shell completions) is
  # kept; the launcher entry below takes its icon from here.
  t3CliFor = pkgs: let
    full = t3codeFor pkgs;
  in
    pkgs.runCommand "t3-${full.version}" {
      meta.mainProgram = "t3";
      passthru.full = full;
    } ''
      mkdir -p "$out/bin" "$out/share"
      ln -s ${full}/bin/t3 "$out/bin/t3"
      for dir in ${full}/share/*; do
        if [ "$(basename "$dir")" != applications ]; then
          ln -s "$dir" "$out/share/"
        fi
      done
    '';

  # V2 can run the app with no backend of its own: with
  # `localEnvironmentEnabled = false` in its desktop-settings.json it skips the
  # local server and serves the UI from its bundled assets ("bootstrap skipping
  # local environment (disabled in settings)"). Left on, that backend shows up
  # as a second environment with the host's name next to the unit, on an
  # empty database of its own (notes.md). No flag or variable sets it, and the
  # app owns the rest of the file (window bounds, update channel), so the
  # wrapper sets just this key before every launch. A file jq cannot parse is
  # left for the app to deal with instead of blocking the launch.
  desktopSettingsFor = pkgs:
    pkgs.writeShellApplication {
      name = "t3code-desktop-settings";
      runtimeInputs = [pkgs.coreutils pkgs.jq];
      text = ''
        doc="$1/userdata/desktop-settings.json"
        mkdir -p "$(dirname "$doc")"
        [ -s "$doc" ] || echo '{}' > "$doc"
        tmp="$(mktemp "$doc.XXXXXX")"
        if jq '.localEnvironmentEnabled = false' "$doc" > "$tmp"; then
          mv "$tmp" "$doc"
        else
          rm -f "$tmp"
        fi
      '';
    };

  # The client: the Electron app, kept off the unit's data by construction.
  # Its only environment is the unit, paired once as a saved environment in
  # Settings → Connections (notes.md has the recipe and what it buys: the
  # preview panel and the agent's `preview_*` tools, which no browser client
  # can have). `T3CODE_HOME` is where the app keeps that pairing and its
  # settings, apart from the unit's `~/.t3`. Before V2 the app *always* forked a
  # backend onto it, and `T3CODE_PORT` kept that backend off the unit's port. It
  # still matters if the local environment is ever switched back on in the UI.
  #
  # A forked backend does not die with the app: when the main Electron
  # process goes away its children are re-parented to `systemd` and the backend
  # keeps `T3CODE_PORT`. The next launch then forks a backend that cannot bind
  # the port, `desktop:get-local-environment-bearer-token` has no local server
  # to mint a session against, and the window dies on
  # `DesktopLocalEnvironmentAuthSessionBootstrapError` — measured 2026-09-19,
  # notes.md. Launching into a transient `--user` service fixes it at the
  # source: the backend lands in that unit's cgroup and the default
  # `KillMode=control-group` reaps it the moment the main process exits, so no
  # stale listener can outlive the app. It must be a service, not a `--scope`:
  # a scope lives as long as *any* process in it, which is exactly the orphan
  # we are trying to kill. A service is started by the `systemd --user`
  # manager, so it inherits that manager's environment (the Wayland session
  # variables niri puts there) and nothing from this shell — hence `--setenv`
  # rather than `export` for the three variables below.
  #
  # `--ozone-platform=wayland` is passed explicitly instead of the NIXOS_OZONE_WL
  # dance in `discord.nix`: nixpkgs' t3code wrapper only prefixes PATH, so it acts
  # on no such variable. Electron's own `--ozone-platform-hint=auto` reads the
  # session environment and was measured falling back to X11 (dying on
  # `Missing X server or $DISPLAY`) when `XDG_SESSION_TYPE` was unset, which a
  # launcher entry cannot guarantee. The explicit flag needs no session state.
  t3codeAppFor = pkgs: let
    full = t3codeFor pkgs;
  in
    pkgs.writeShellApplication {
      name = "t3code-desktop";
      runtimeInputs = [pkgs.systemd];
      text = ''
        home="''${XDG_DATA_HOME:-$HOME/.local/share}/t3code-desktop"
        ${pkgs.lib.getExe (desktopSettingsFor pkgs)} "$home"
        exec systemd-run --user --collect \
          --description="T3 Code desktop client" \
          --setenv=T3CODE_HOME="$home" \
          --setenv=T3CODE_PORT=3799 \
          --setenv=SSL_CERT_FILE=${caBundle} \
          -- ${full}/bin/t3code-desktop --ozone-platform=wayland "$@"
      '';
    };
in {
  flake.modules = {
    nixos = {
      # The client. See notes.md.
      t3code = {pkgs, ...}: {
        environment.systemPackages = [(t3codeAppFor pkgs)];
      };

      # Without lingering, a user service only exists between login and logout —
      # which defeats the point of reaching this machine from a phone. `hostUsers`
      # is the loader's account → features map, so only the accounts that actually
      # enable this feature get it.
      t3code-server = {
        lib,
        pkgs,
        hostUsers ? {},
        ...
      }: {
        users.users =
          lib.genAttrs
          (lib.filter (u: builtins.elem "t3code-server" hostUsers.${u}) (builtins.attrNames hostUsers))
          (_: {linger = true;});

        # The server renders previews (browser tabs,
        # `html_render`) in a headless Chrome it downloads into ~/.t3/tools.
        # That binary is foreign, so it loads through nix-ld, whose base set
        # has none of Chrome's libraries — every `preview_open` failed with
        # "This host is missing libraries T3's browser needs". Upstream's fix,
        # `sudo t3 browser setup`, apt-installs Chrome's Debian deps (its
        # DEBIAN_PACKAGES); this is the same list for NixOS. T3 checks with the
        # browser's own `--version`, not ldd, so nix-ld is enough, and the
        # running server already reads /run/current-system/sw/share/nix-ld — no
        # restart. Chrome's sandbox needs nothing more here (measured
        # 2026-10-19). See notes.md.
        programs.nix-ld.libraries = with pkgs; [
          glib
          nspr
          nss
          atk
          at-spi2-atk
          at-spi2-core
          dbus
          expat
          libgbm
          libx11
          libxcomposite
          libxdamage
          libxext
          libxfixes
          libxrandr
          libxcb
          libxkbcommon
          systemd # libudev
          alsa-lib
        ];

        # The server browser is Google Chrome (see `browserDisplay`), which reads
        # managed policy from here. Bitwarden's popup is browser chrome the JPEG
        # stream never shows, but its inline autofill menu is drawn into the page.
        environment.etc."opt/chrome/policies/managed/t3code-server.json".text = builtins.toJSON {
          ExtensionInstallForcelist = [
            "${bitwardenExtensionId};https://clients2.google.com/service/update2/crx"
          ];
          # The panel streams a tab through a CDP session of its own, and by
          # default (0) Chrome refuses DevTools on the pages of policy-installed
          # extensions: Bitwarden's popup tab showed "Browser connection was
          # refused" (`Target.attachToTarget: Not allowed`). 1 allows it.
          DeveloperToolsAvailability = 1;
        };
      };
    };

    homeManager = {
      t3code = {...}: {
        xdg.desktopEntries.t3code = {
          name = "T3 Code";
          exec = "t3code-desktop";
          icon = "t3code"; # from the CLI package's share/icons, kept above
          terminal = false;
          categories = ["Development"];
          # The app_id the Electron app reports, measured on 2026-09-05 with
          # `niri msg -j windows`. Re-measure with the same command after a
          # major t3code bump.
          settings.StartupWMClass = "t3code";
        };
      };

      # The server: `t3 serve`, published on the tailnet, per account.
      t3code-server = {
        pkgs,
        lib,
        ...
      }: let
        t3 = t3CliFor pkgs;
      in {
        home.packages = [t3];

        # The server browser's virtual display (see `browserDisplay`). 4K so the
        # 2× browser has room for its 1280×800 viewport and the page's `screen`
        # is a real monitor's rather than the viewport's.
        systemd.user.services.t3code-display = {
          Unit.Description = "Virtual X display for the T3 Code server's browser";
          Service = {
            ExecStart = "${pkgs.xvfb}/bin/Xvfb ${browserDisplay} -screen 0 3840x2160x24 -nolisten tcp -noreset";
            Restart = "on-failure";
          };
          Install.WantedBy = ["default.target"];
        };

        systemd.user.services.t3code = {
          Unit = {
            Description = "T3 Code server, published on the tailnet over Tailscale Serve";
            Wants = ["t3code-display.service"];
            After = ["t3code-display.service"];
          };

          Service = {
            # `serve` = start headless and print the pairing token, URL and QR code
            # (they land in the journal; `t3 pair` mints a fresh one on demand).
            # `--tailscale-serve` makes Tailscale Serve terminate HTTPS on the
            # MagicDNS name and proxy to this backend, which is why the listener
            # stays on loopback and no firewall port is opened. HTTPS is what lets
            # the phone use https://app.t3.codes — browsers block an HTTPS page
            # from opening a plain ws:// backend.
            ExecStart = "${lib.getExe t3} serve --host 127.0.0.1 --port 3773 --no-browser --tailscale-serve";
            WorkingDirectory = "%h";
            # tailscaled is a *system* unit, so a user unit cannot order against it.
            # `tailscale serve` fails until the tailnet is up, so retry instead.
            Restart = "on-failure";
            RestartSec = 10;
            # A user unit inherits nothing from the login shell, so this is the
            # only place the server (and the providers it spawns) can learn
            # where the CA bundle is. See `caBundle` above.
            Environment = [
              "SSL_CERT_FILE=${caBundle}"
              # Not DISPLAY: the server imports the login shell's environment,
              # whose DISPLAY/WAYLAND_DISPLAY are the niri session (notes.md).
              "T3CODE_SERVER_BROWSER_DISPLAY=${browserDisplay}"
              "T3CODE_SERVER_BROWSER_EXECUTABLE=${lib.getExe pkgs.google-chrome}"
            ];
          };

          Install.WantedBy = ["default.target"];
        };
      };
    };
  };

  flake.featureMeta.t3code = {
    # The app is paired to *this* host's unit, and takes its icon from the CLI
    # package `t3code-server` installs, so the server belongs on the same host.
    # A machine that only wants to *reach* another host's t3code needs no
    # feature at all — it opens the tailnet URL in a browser (and gets no
    # preview there; notes.md).
    requires = ["desktop" "t3code-server"];
    kind = "gui";
    provides.systemBins = ["t3code-desktop"];
  };

  # feature test: the app needs a live niri session and a paired environment, so
  # the launcher entry and the wrapper's contract are as far as a headless VM
  # reaches. The entry can't be a `provides.userFiles` line: home-manager
  # installs `xdg.desktopEntries` as a *package* (home.packages), so under
  # `useUserPackages` it lands in the account's profile — a path that carries the
  # login and therefore can't be written as a static declaration.
  flake.featureTests.t3code = {
    # The same Electron the package runs on (nixpkgs' default `electron`), and
    # jq to read back the app's settings file.
    extraNixosModules = [({pkgs, ...}: {environment.systemPackages = [pkgs.electron pkgs.jq];})];
    testScript = ''
      entry = "/etc/profiles/per-user/tester/share/applications/t3code.desktop"
      machine.succeed(f"test -e {entry}")
      machine.succeed(f"grep -qx 'Exec=t3code-desktop' {entry}")
      machine.succeed(f"grep -qx 'StartupWMClass=t3code' {entry}")

      # The two variables that keep the app's own backend off the unit's
      # database and port, and the flag without which it dies on a Wayland-only
      # session. Losing any of them is silent at eval time.
      wrapper = machine.succeed("command -v t3code-desktop").strip()
      machine.succeed(f"grep -q 'T3CODE_HOME=' {wrapper}")
      machine.succeed(f"grep -q 'T3CODE_PORT=3799' {wrapper}")
      machine.succeed(f"grep -q -- '--ozone-platform=wayland' {wrapper}")

      # The app's backend only gets reaped with the app because the wrapper
      # launches into a transient user *service*. A plain exec (or a --scope)
      # leaks the backend onto 3799 and bricks the next launch (notes.md).
      machine.succeed(f"grep -q 'systemd-run --user --collect' {wrapper}")
      machine.fail(f"grep -q -- '--scope' {wrapper}")

      # Without this the Antigravity provider's embedded Python has no trust
      # store and every model call comes back as a bogus 502 (see notes.md).
      machine.succeed(f"grep -q 'SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt' {wrapper}")

      # The app must not start a local backend of its own: the unit is its only
      # environment (see `desktopSettingsFor`). The wrapper runs the settings
      # step before every launch; drive it directly against three states.
      settings_bin = machine.succeed(
          f"grep -o '/nix/store/[^ ]*/bin/t3code-desktop-settings' {wrapper}"
      ).strip()
      home = "/tmp/t3home"
      doc = f"{home}/userdata/desktop-settings.json"
      local = "jq -e '.localEnvironmentEnabled == false'"

      # First launch: no settings file yet.
      machine.succeed(f"{settings_bin} {home}")
      machine.succeed(f"{local} {doc}")

      # The app's own keys (window bounds, update channel) survive the rewrite.
      machine.succeed(
          f"echo '{{\"localEnvironmentEnabled\":true,\"updateChannel\":\"nightly\"}}' > {doc}"
      )
      machine.succeed(f"{settings_bin} {home}")
      machine.succeed(f"{local} {doc}")
      machine.succeed(f"jq -e '.updateChannel == \"nightly\"' {doc}")

      # A file jq cannot parse is left alone, and the launch still goes ahead.
      machine.succeed(f"echo 'not json' > {doc}")
      machine.succeed(f"{settings_bin} {home}")
      machine.succeed(f"grep -qx 'not json' {doc}")

      # The app's backend runs under Electron, and node-pty's native module
      # must load there, or the backend dies at startup with
      # NodePtyModuleLoadError and the app never opens a window. Electron (unlike
      # nodejs) does not pull in libstdc++, which the prebuilt `pty.node` needs
      # (see `t3codeFor`) — so this has to be Electron, not a bare node.
      pkg = machine.succeed(
          "dirname $(dirname $(readlink -f /etc/profiles/per-user/tester/bin/t3))"
      ).strip()
      machine.succeed(
          "ELECTRON_RUN_AS_NODE=1 electron -e 'require(process.argv[1])' "
          + f"{pkg}/libexec/t3code/node_modules/.pnpm/node-pty@*/node_modules/node-pty"
      )

      # Electron finds the app's safeStorage key in the keyring by productName,
      # so a rename orphans every saved environment (see `keyringName`).
      machine.succeed(
          "grep -qF '\"productName\": \"${keyringName}\"' "
          + f"{pkg}/libexec/t3code/apps/desktop/package.json"
      )

      # "Open in VS Code" on the unit (loopback) is a local `vscode://file`
      # link, not SSH: the client must build it and the app's shell must let
      # it through (`open-local-editor.patch`).
      machine.succeed(f"grep -Rlq 'this-machine' {pkg}/libexec/t3code/apps/server/dist/client/assets/")
      machine.succeed(f"grep -q 'isLocalEditorUrl(url)' {pkg}/libexec/t3code/apps/desktop/dist-electron/main.cjs")
    '';
  };

  flake.featureMeta.t3code-server = {
    requires = ["tailscale"];
    kind = "service";
    # The unit's whole job is to publish itself on a tailnet. A VM has no tailnet
    # to join, so `tailscale serve` — and with it the service — cannot come up;
    # the feature test guards eval, the unit being installed, and the CLI.
    runtimeUntestable = true;
    provides = {
      userBins = ["t3"];
      userFiles = [
        ".config/systemd/user/t3code.service"
        ".config/systemd/user/t3code-display.service"
      ];
      files = ["/etc/opt/chrome/policies/managed/t3code-server.json"];
    };
  };

  # feature test: `provides` covers the CLI and the unit file existing; the one
  # thing a declaration cannot express is what the unit puts in the *environment*
  # of the providers it spawns — and that single variable is the difference
  # between Antigravity answering and every turn failing as a 502 (notes.md).
  flake.featureTests.t3code-server = {
    extraNixosModules = [({pkgs, ...}: {environment.systemPackages = [pkgs.jq pkgs.curl];})];
    testScript = ''
      unit = "/home/tester/.config/systemd/user/t3code.service"
      machine.succeed(
          f"grep -q 'Environment=SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt' {unit}"
      )

      # The server's headless Chrome (previews, html_render) is a downloaded
      # binary that loads through nix-ld; each of these is a library its
      # loader refused on this host before (see `programs.nix-ld.libraries`
      # in `nixos.t3code-server`).
      for lib in [
          "libglib-2.0.so.0", "libgobject-2.0.so.0", "libgio-2.0.so.0",
          "libnspr4.so", "libnss3.so", "libnssutil3.so",
          "libatk-1.0.so.0", "libatk-bridge-2.0.so.0", "libatspi.so.0",
          "libdbus-1.so.3", "libexpat.so.1", "libgbm.so.1",
          "libX11.so.6", "libXcomposite.so.1", "libXdamage.so.1",
          "libXext.so.6", "libXfixes.so.3", "libXrandr.so.2", "libxcb.so.1",
          "libxkbcommon.so.0", "libudev.so.1", "libasound.so.2",
      ]:
          machine.succeed(f"test -e /run/current-system/sw/share/nix-ld/lib/{lib}")

      # Agent tabs reach the human as the server's JPEG stream; the patched
      # quality must survive into the bundled server (see `streamQuality`).
      # `--replace-fail` guards the source side; this guards the bundler.
      dist = machine.succeed(
          "dirname $(dirname $(readlink -f /etc/profiles/per-user/tester/bin/t3))"
      ).strip() + "/libexec/t3code/apps/server/dist"
      machine.succeed(f"grep -q 'DEFAULT_QUALITY = ${toString streamQuality};' {dist}/*.mjs")
      machine.succeed(
          f"grep -q 'SCREENCAST_MOTION_QUALITY = ${toString streamMotionQuality};' {dist}/*.mjs"
      )

      # The server browser is a full Chrome, run headed on the unit's own
      # display (see `browserDisplay`). The patch must survive into the bundle,
      # and the unit must hand the server both the browser and the display.
      machine.succeed(f"grep -q 'T3CODE_SERVER_BROWSER_EXECUTABLE' {dist}/*.mjs")
      # Bitwarden's popup is reachable only as a tab of its own page.
      machine.succeed(f"grep -q '\"chrome-extension:\"' {dist}/*.mjs")
      machine.succeed(
          f"grep -q 'Environment=T3CODE_SERVER_BROWSER_DISPLAY=${browserDisplay}' {unit}"
      )
      # The headed browser is pinned to that display and to X11, whatever
      # session the login shell's environment points at.
      machine.succeed(f"grep -q 'T3CODE_SERVER_BROWSER_DISPLAY' {dist}/*.mjs")
      machine.succeed(f"grep -q -- '--ozone-platform=x11' {dist}/*.mjs")
      chrome = machine.succeed(
          f"grep -oP 'T3CODE_SERVER_BROWSER_EXECUTABLE=\\K\\S+' {unit}"
      ).strip()

      # The display comes up with the account's user manager (linger), and
      # Chrome starts headed on it: it only prints its DevTools endpoint once
      # its browser process is up, and it dies at once without a display.
      machine.wait_for_unit("t3code-display.service", "tester")
      machine.wait_for_file("/tmp/.X11-unix/X${browserDisplayNumber}")
      machine.succeed(
          f"su tester -c 'DISPLAY=${browserDisplay} timeout 60 {chrome} "
          + "--user-data-dir=$(mktemp -d) --remote-debugging-port=9222 "
          + "--no-first-run about:blank' > /tmp/chrome.log 2>&1 &"
      )
      machine.wait_until_succeeds("grep -q 'DevTools listening on ws://' /tmp/chrome.log", timeout=60)
      machine.succeed("curl -sf http://127.0.0.1:9222/json/version | grep -q '\"Browser\": \"Chrome/'")

      # Bitwarden is force-installed by Chrome's managed policy.
      machine.succeed(
          "jq -e '(.ExtensionInstallForcelist[0] | startswith(\"${bitwardenExtensionId};\"))"
          + " and .DeveloperToolsAvailability == 1' "
          + "/etc/opt/chrome/policies/managed/t3code-server.json"
      )
    '';
  };
}
