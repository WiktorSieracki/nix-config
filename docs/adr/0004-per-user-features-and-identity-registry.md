# Per-user features: the loader creates accounts, identity in `meta.users`

The need for a second, isolated account (`work`) with *the same environment but a
different identity* (git, profiles, secrets) exposed that a specific login was
wired into the architecture: the loader attached HM exclusively to `wiktor`, half
the graph had `requires = ["wiktor"]`, and features set `users.users.wiktor.*`
hardcoded. Decision: **the host declares users, not the features**.

- `features.json` changes format from a flat list to `{ "system": [...],
  "users": { "<login>": [...] } }` (updates ADR 0003). A feature's NixOS part
  activates when the feature appears anywhere; its HM part goes only to the users
  that list it. `requires` validation for a user feature is computed against
  `system ∪ users.<login>`.
- The loader creates an account for each key of the `users` section; the account
  data (full name, groups — including `wheel` explicitly — shell, secret
  references: email, password hash) live in the registry
  `flake.meta.users.<login>` alongside the existing `flake.meta.programs`. A user
  feature receives its identity injected and knows no login; the foundation
  features `wiktor` and `work-user` dissolve, and `requires = ["wiktor"]`
  disappears from the graph.
- Per-user secrets (the work email, the work password hash) are provided by
  **system** sops with `owner = <login>` — HM sops is out, because it decrypts
  with a key from the main user's home (mode 700), unreadable to other accounts.
  wiktor's email migrates to the same mechanism (one delivery path).
- A user feature's feature test uses the neutral `tester` account — a smuggled-in
  hardcoded login breaks the test (enforcing the rule structurally, ADR 0002).
  Isolation between accounts (home 700, no sudo, per-user package invisibility) is
  asserted by the loader *mechanism* test with two test accounts, not by a
  feature.

Rejected: a foundation feature per account (`featureMeta.requires` can't express
"wiktor OR work"; that's the same ugliness as "git with two users", just in the
graph); a dedicated age key for `work` (it would decrypt the whole
`secrets.yaml`, and splitting into per-recipient files is a lot of machinery for
one email); a standalone rebuild from the `work` account (the right to
`nh os switch` = root = the end of isolation — `work` is a managed account). A
consequence to accept: the NixOS part of a feature enabled for just one user
still works system-wide — app invisibility between accounts is held by features
installing through HM (`home.packages`/`programs.*`), not
`environment.systemPackages`.
