# claude-agent-acp — feature notes

2026-07-26: Added the feature.

Upstream is the npm package `@agentclientprotocol/claude-agent-acp`, but it is
packaged for us by the `llm-agents` flake input (numtide/llm-agents.nix), which
already carries it as `packages.<system>.claude-agent-acp` — same input the
`claude-code` and `pi` features use. No hand-rolled `buildNpmPackage` needed;
bumping the version means bumping that flake input.

The version from `llm-agents` can lag the npm registry (0.61.0 vs 0.62.0 at the
time of writing). That's fine — ACP negotiates `protocolVersion` in the
handshake, so a slightly older adapter still talks to a current frontend.

Why this exists as its own feature rather than living inside
`agent-of-empires`: the adapter is a generic ACP server, not an aoe component.
Any ACP client (Zed, aoe's Structured view, …) spawns the same binary by name
off `$PATH`, which is the *only* wiring — there is no config file and no
registration step. `agent-of-empires` therefore just `requires` it.

`claude-agent-acp` is a distinct binary from `claude` (the `claude-code`
feature) and does not need it on `$PATH` to answer `initialize` — its feature
test boots with an empty `requires` and passes. Actually driving a prompt
through it does need Claude credentials, which is why the test stops at the
handshake.
