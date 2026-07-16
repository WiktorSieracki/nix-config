# feature notes — typst

## 2026-06-26

Symptom: `typst-live` is a live-preview tool (likely a wrapper that starts an HTTP server). We don't test it in the feature test, since it needs a `.typ` file and a browser.
Cause: The `tinymist` binary is an LSP server for typst — it has no `--version` flag; it runs with or without an argument, but with no arguments it may hang waiting on stdio.
Fix: The feature test is limited to `typst --version` and `typstyle --version` — they always return exit 0 with no side effects.
