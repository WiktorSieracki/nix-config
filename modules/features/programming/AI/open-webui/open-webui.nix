{...}: {
  flake.modules.nixos.open-webui = {
    services.open-webui = {
      enable = true;
      # Local only (127.0.0.1:8080, firewall closed) — a personal single-user
      # chat UI in front of the local ollama daemon.
      host = "127.0.0.1";
      port = 8080;
      environment = {
        OLLAMA_BASE_URL = "http://127.0.0.1:11434";
        # No OpenAI backend — local ollama is the only provider; leaving this on
        # makes the UI stall probing api.openai.com without a key.
        ENABLE_OPENAI_API = "False";
        # Single local user behind loopback — skip the login/signup wall.
        WEBUI_AUTH = "False";
        # Don't phone home for version checks.
        ENABLE_VERSION_UPDATE_CHECK = "False";
      };
    };
  };

  # Talks to the ollama HTTP API, so the daemon must be enabled on the same
  # host. kind=service: web UI is a systemd service testable headlessly in a VM.
  flake.featureMeta.open-webui = {
    requires = ["ollama"];
    kind = "service";
  };

  # feature test: daemon and UI both come up, the UI serves its frontend, and it
  # can reach ollama through its own API proxy (proves OLLAMA_BASE_URL wiring).
  flake.featureTests.open-webui = {
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("ollama.service")
      machine.wait_for_unit("open-webui.service")
      machine.wait_for_open_port(11434)
      machine.wait_for_open_port(8080)
      # First start runs DB migrations — poll until the app answers. The served
      # index.html doesn't literally contain "open-webui", so probe /health.
      machine.wait_until_succeeds("curl -sf http://127.0.0.1:8080/health", timeout=120)
      machine.succeed("curl -sf http://127.0.0.1:8080/")
      # /ollama/* is open-webui's proxy to OLLAMA_BASE_URL — a 200 here proves
      # the UI actually reaches the local daemon. The proxy requires a session
      # even with WEBUI_AUTH=False, but then signin hands out the admin token
      # without credentials.
      import json
      signin = machine.succeed(
          "curl -sf -X POST -H 'Content-Type: application/json'"
          " -d '{\"email\":\"\",\"password\":\"\"}'"
          " http://127.0.0.1:8080/api/v1/auths/signin"
      )
      token = json.loads(signin)["token"]
      machine.succeed(f"curl -sf -H 'Authorization: Bearer {token}' http://127.0.0.1:8080/ollama/api/version")
    '';
  };
}
