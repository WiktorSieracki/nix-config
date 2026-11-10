# feature notes — docker

## 2026-11-10 — the daemon also started in system accounts' sessions

Symptom: `docker.service: Failed with result 'exit-code'` / `start-limit-hit` in the journal under uid 175 (`sddm`) every time the greeter came up — 12 failed starts in two weeks on the desktop.
Cause: nixpkgs installs the unit as `wantedBy = default.target` for every user's systemd instance and only excludes root (`ConditionUser=!root`). The greeter's account gets an instance too, and a system account has no subuid range for rootlesskit.
Fix: `ConditionUser=!@system` on the unit. The feature test now runs the daemon for real (`provides.userUnits`, a container through it) and checks that a lingering system account skips the unit.

## 2026-06-26

> **[2026-11-10]** The first entry below is superseded: the daemon is tested
> through `provides.userUnits`, which lets the test account linger so its
> systemd instance exists without a login.

Symptom: `virtualisation.docker.rootless` installs the daemon as a systemd *user* service, not a system service. `machine.wait_for_unit("docker.service")` in nixosTest fails because there's no user session.
Cause: Rootless Docker runs in the user's context (`systemctl --user`). nixosTest doesn't start a user session automatically.
Fix: The feature test is limited to `docker --version` (the CLI is available system-wide). If a daemon test is needed in the future, add a machine with autologin and check `su - <user> -c 'systemctl --user status docker.service'` after login.

Symptom: `hardware.graphics.enable32Bit = true` causes 32-bit Mesa libraries to build in nixosTest (unnecessary, slow).
Cause: The option exists for NVIDIA/gaming support, it's not required by the docker CLI.
Fix: The feature test overrides that option with `lib.mkForce false` via `extraNixosModules`.
