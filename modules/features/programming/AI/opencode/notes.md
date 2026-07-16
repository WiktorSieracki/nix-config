# opencode — feature notes

2026-07-11: Split out of the former `llm-agents` feature (split into `claude-code`, `opencode`, `pi`).

The feature pulls the package from the external flake `github:numtide/llm-agents.nix`. Binary: `opencode` → `opencode`.

Symptom: The eval may be slow on first build due to a missing numtide cache.
Cause: The numtide/llm-agents.nix flake advertises its own substituters (`cache.numtide.com`), but they aren't trusted by default.
Fix: Add `https://cache.numtide.com` to `nix.settings.substituters`, or build locally.
