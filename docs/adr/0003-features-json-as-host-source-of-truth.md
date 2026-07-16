# Host feature lists in data files (features.json), not in Nix

Real hosts (`desktopNixos`, `laptopNixos`) keep their feature list in
`modules/hosts/<host>/features.json` (a flat list of names), read by `default.nix`
via `builtins.fromJSON`. Reason: the list must be *writable* by an external tool
(**Switchboard**, the TUI for enabling features), and editing Nix syntax from the
outside is perpetually brittle (comments, formatting). Rejected alternatives:
parsing/editing `.nix` from a CLI, and one global `hosts.json` (it would break the
folder-per-host symmetry). Cost: the sectional category-comments in the lists
disappear (consciously accepted). Image hosts (`iso`, `vm`) stay with inline
lists — they aren't a Switchboard target. `requires` validation stays in the
loader (ADR 0002) — the data file auto-pulls nothing; Switchboard writes the
closure explicitly.

**Update (ADR 0004):** the format is no longer a flat list — `features.json` is
`{ "system": [...], "users": { "<login>": [...] } }`, separating machine features
from per-account features. The rest of the decision (data file, writability by
Switchboard, no auto-pulling) holds unchanged.
