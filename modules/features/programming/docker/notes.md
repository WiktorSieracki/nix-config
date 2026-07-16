# feature notes — docker

## 2026-06-26

Symptom: `virtualisation.docker.rootless` installs the daemon as a systemd *user* service, not a system service. `machine.wait_for_unit("docker.service")` in nixosTest fails because there's no user session.
Cause: Rootless Docker runs in the user's context (`systemctl --user`). nixosTest doesn't start a user session automatically.
Fix: The feature test is limited to `docker --version` (the CLI is available system-wide). If a daemon test is needed in the future, add a machine with autologin and check `su - <user> -c 'systemctl --user status docker.service'` after login.

Symptom: `hardware.graphics.enable32Bit = true` causes 32-bit Mesa libraries to build in nixosTest (unnecessary, slow).
Cause: The option exists for NVIDIA/gaming support, it's not required by the docker CLI.
Fix: The feature test overrides that option with `lib.mkForce false` via `extraNixosModules`.
