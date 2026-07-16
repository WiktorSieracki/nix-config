# localsend — feature notes

2026-06-26: Added featureMeta + a feature test.

Symptom: `command -v localsend` returns "not found" despite the package being installed.
Cause: The upstream Flutter build names the binary `localsend_app`, not `localsend`.
Fix: The feature test asserts `command -v localsend_app`.
