# feature notes: ssh

The SSH client configuration feature via HM (`programs.ssh`) with matchBlocks and ssh-agent.

## Gotchas

**2026-06-26** — HM generates `~/.ssh/config` from `programs.ssh.matchBlocks`. The file isn't created if `home-manager-wiktor.service` doesn't finish successfully.
The feature test waits for `home-manager-wiktor.service` before asserting `test -f ~/.ssh/config`.

**2026-06-26** — Deprecation warnings from HM: `matchBlocks.<host>.extraOptions` is deprecated in favour of `programs.ssh.settings.<host>`. It doesn't block the build or the test — just a warning at eval. Migration to the new format is deferred to a feature refactor.
