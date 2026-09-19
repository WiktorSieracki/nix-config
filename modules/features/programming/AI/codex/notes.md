# codex — feature notes

OpenAI's Codex CLI, from the `llm-agents` input (same source as `claude-code`,
`opencode` and `pi`, so it comes from numtide's binary cache rather than a local
Rust build).

2026-09-19: Added. Codex reads skills from `~/.agents/skills` (it also scans
`$CWD/.agents/skills` and the repo root), which the skill features
(`mattpocock-skills`, `local-skills`) already link into — so
enabling this feature is all that is needed for the skills to show up in a codex
session.
