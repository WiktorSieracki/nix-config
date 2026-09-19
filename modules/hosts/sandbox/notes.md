# Live sandbox — feature notes

Non-executable knowledge about the sandbox host itself. Reproducible facts belong
in `checks.sandbox-eval` or a feature's `check.sh`; this file holds what a test
cannot express.

## 2026-09-19 — virtiofs needs shared memory, or the guest never boots

**Symptom:** `sandbox up` builds fine, QEMU starts, the window appears — and
nothing else happens. No console, no ssh. The journal repeats
`vhost_set_vring_kick failed: Input/output error`, `Error starting vhost: 5`,
and virtiofsd logs `Waiting for daemon failed: HandleRequest(InvalidParam)`.

**Cause:** the guest gets `/nix/store` over virtiofs (`vhost-user-fs`), which
requires QEMU's guest RAM to be a shareable `memfd`. nixpkgs enables the
virtiofs *shares* by default (`mountHostNixStore`) but leaves
`virtualisation.qemu.enableSharedMemory` off (`mkEnableOption`, default false),
so the two halves disagree and the store never mounts.

**Fix:** `virtualisation.qemu.enableSharedMemory = true` in the sandbox host.

The `vm` host (`modules/hosts/vm/`) has the same gap — verified with
`nix eval .#nixosConfigurations.vm.config.virtualisation.vmVariant.virtualisation.qemu.enableSharedMemory`
→ `false`. Left alone for now; it is a one-line fix when someone touches it.

## 2026-09-19 — the deployable system and the bootable system must be one

**Symptom:** `sandbox deploy <f>` dies in eval with *"The ‘fileSystems’ option
does not specify your root file system"*, even though the same host boots.

**Cause:** with `virtualisation.vmVariant`, the root filesystem exists only in
the VM variant. `nixos-rebuild --target-host` builds plain
`config.system.build.toplevel`, which therefore has no root and cannot
evaluate — the machine boots but nothing can ever be installed into it.

**Fix:** import `virtualisation/qemu-vm.nix` directly instead of going through
`vmVariant`, so the host's own toplevel *is* the VM. `build-vm.nix` defines
`system.build.vm` with `mkDefault`, so importing qemu-vm overrides it cleanly.

## 2026-09-19 — a deploy that ends in grub-install

**Symptom:** `deploy` copies the whole closure, then fails at the last step:
`grub-install: error: will not proceed with blocklists` / `Failed to install
bootloader`, leaving the machine half-switched.

**Cause:** the `core` floor enables GRUB. The sandbox boots its kernel directly
(`-kernel`/`-initrd`) and has no ESP, so there is nothing to install into.

**Fix:** `boot.loader.grub.enable = lib.mkForce false` in the sandbox host.

## 2026-09-19 — ssh eats the quoting you thought you had

**Symptom:** `wait_for_session` timed out for two minutes while niri had in fact
been running the whole time.

**Cause:** ssh joins its arguments with spaces and hands the result to the remote
*shell*. `guest sh -c 'test -n "$NIRI_SOCKET" && niri msg version'` arrives
unquoted: `$NIRI_SOCKET` expands in the remote login shell (empty), and the
`&& …` half runs outside `sandbox-env` entirely. Every probe command was
affected, not just this one.

**Fix:** the runner re-quotes each argument with `printf '%q '`, so the remote
shell reconstructs exactly the words that were passed.

## 2026-09-19 — OPEN: the guest session has no seat, so it receives no input

**Symptom:** the agent can *look* but not *click*. niri renders, `niri msg`
works, `grim` works, but no synthetic input reaches the compositor: niri's
startup hotkey overlay stays on screen through every attempt, and `Super+O`
(overview) does nothing. Tried and rejected: `wtype` (exit 0, virtual-keyboard
protocol — reaches clients, never the compositor), `ydotool` (exit 0, with and
without the unit's `PrivateUsers`/`DevicePolicy` hardening), QMP `send-key`
(device-level injection, also no effect).

**Cause (diagnosed, not yet fixed):** the tester's graphical session is not on a
seat. In the guest:

```
loginctl list-seats            → seat0 (exists)
loginctl show-session 3        → Class=manager  Seat=  TTY=
/proc/<niri pid>/cgroup        → user@1000.service/session.slice/niri.service
ls -l /dev/input/event*        → root:input 660, no per-session ACL
```

There is no `Class=user Seat=seat0` session for the SDDM autologin at all, so
logind hands out no input-device ACLs and libseat's logind backend has no
session to take devices from. niri still renders because `tester` is in the
`video` group and can open `/dev/dri/card0` directly — which is exactly why the
failure looks like "input is broken" rather than "the session is wrong".

**Likely fix to try next:** give the sandbox a real seat0 session — getty
autologin on tty1 starting `niri-session` from the shell — instead of SDDM
autologin. Cheaper and closer to how a headless test VM should work, at the cost
of no longer exercising the greeter (which `sddm-theme` would want).

**Until then:** the sandbox verifies *what is on screen* and *what the
compositor reports*, plus anything reachable through `niri msg action` and
client-level typing. It cannot yet verify that a **keybind** is wired — only
that the action behind it works.
