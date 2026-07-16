# feature notes: ssh-server

The OpenSSH server feature with password authentication disabled and a public key for the wiktor user.

## Gotchas

**2026-06-26** — On NixOS `services.openssh.enable = true` creates the unit `sshd.service` (not `ssh.service`).
The feature test asserts `sshd.service` — that's the correct name on NixOS (unlike Debian, where it may be `ssh.service`).

**2026-06-26** — `PermitRootLogin = "no"` and `PasswordAuthentication = false` mean the feature-test VM can't be debugged via a root password. If debugging is needed, add a test key to `extraNixosModules`.
