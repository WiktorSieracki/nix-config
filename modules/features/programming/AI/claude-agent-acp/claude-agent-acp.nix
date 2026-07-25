{inputs, ...}: {
  flake.modules.nixos.claude-agent-acp = {pkgs, ...}: {
    # The official ACP (Agent Client Protocol) adapter for Claude. ACP frontends
    # — e.g. agent-of-empires' Structured view — don't talk to Claude directly;
    # they spawn `claude-agent-acp` and speak JSON-RPC to it over stdio.
    environment.systemPackages = [
      inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-agent-acp
    ];
  };

  flake.featureMeta.claude-agent-acp = {
    requires = [];
    kind = "cli";
  };

  # feature test: binary name from meta.mainProgram → "claude-agent-acp".
  # The `command -v` check alone would pass on a broken node bundle, so the real
  # assertion is the ACP handshake: the adapter is a stdio JSON-RPC server, and
  # `initialize` is the one method that needs no auth, no network and no session.
  flake.featureTests.claude-agent-acp = {
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("command -v claude-agent-acp")

      req = '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":1,"clientCapabilities":{"fs":{"readTextFile":false,"writeTextFile":false}}}}'
      out = machine.succeed("echo '" + req + "' | claude-agent-acp")
      assert '"agentInfo"' in out, f"no ACP initialize response: {out}"
      assert "claude-agent-acp" in out, f"unexpected agent identity: {out}"
    '';
  };
}
