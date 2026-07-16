# Running the vm host

**Preferred way to actually boot and test the `vm` host** is the NixOS-generated VM
runner — *not* the raw disk image. The runner wraps the config in `qemu-vm.nix`, which
attaches the rootfs to a virtio disk QEMU knows how to mount and creates a scratch
`./nixos-vm.qcow2` overlay. **By default that overlay persists across runs**, but the
VM exists to test config reproducibility, so prefer a clean boot every time: point
`NIX_DISK_IMAGE` at a throwaway path (the `run-vm-windowed` launcher does exactly this
and deletes it on exit). To persist instead, drop the `NIX_DISK_IMAGE` line.

```bash
SDL_VIDEODRIVER=wayland \
  NIX_DISK_IMAGE=$(mktemp -u --tmpdir nixos-vm.XXXXXX.qcow2) \
  QEMU_OPTS="-m 4096 -smp 4 -vga none -device virtio-vga-gl -display sdl,gl=on -full-screen \
    -audiodev pipewire,id=snd0 -device ich9-intel-hda -device hda-duplex,audiodev=snd0" \
  nix run .#nixosConfigurations.vm.config.system.build.vm
```

- `-vga none` is required because the runner doesn't set a VGA device; without it,
  QEMU adds a default VGA *and* the `virtio-vga-gl` you pass → "multiple VGA" error.
- **Sound:** the runner adds no audio device, so the guest pipewire finds no card and
  there's no sound. Pass `-audiodev pipewire,id=snd0 -device ich9-intel-hda -device
  hda-duplex,audiodev=snd0` (host runs pipewire); the guest then exposes a
  `Built-in Audio Analog Stereo` sink (verified: a guest tone shows up as a running
  `qemu-system-x86_64` Stream/Output/Audio on the host). `hda-duplex` also wires a mic.
- It auto-logs into wiktor's niri session. Password (sudo / unlock) is `nixos`.
- **Passing `Mod`/Super hotkeys to the guest:** the host niri grabs Super first.
  Press `Ctrl+Alt+G` to grab — SDL2 then requests `zwp_keyboard_shortcuts_inhibit`,
  which niri grants, forwarding all keys (incl. Mod binds) *and the mouse* to the
  guest; `Ctrl+Alt+G` again releases. **Use SDL on Wayland, not GTK** (both verified
  by injecting keys with ydotool): QEMU's GTK backend does *not* request the
  inhibitor on niri, so `gtk` leaves Super bound to the host and the grab appears to
  do nothing (and the mouse dies). `SDL_VIDEODRIVER=wayland` is essential — bare SDL
  falls back to Xwayland (no inhibit) and fails the same way.
- **Terminal inside the VM:** `ghostty` (the default terminal) does *not* render
  under the nested virgl GL, so `Mod+Return` opens nothing. Other GUI apps are fine
  (`Mod+E` → nautilus, `Mod+B` → browser). Add a lighter terminal (e.g. `foot`) to
  the `vm` host if you need a shell window in the guest.
- **Headless verification (no GUI):** add `-display none` plus
  `-serial unix:/tmp/vm-ser.sock,server,nowait` to `QEMU_OPTS`, then connect with
  `socat -,raw,echo=0 UNIX-CONNECT:/tmp/vm-ser.sock` and log in as `wiktor`/`nixos`.

The raw qcow2 from `nh os build-image -H vm --image-variant qemu-efi` (the `./result`
symlink) will **not** boot under plain QEMU — the `vm` host has no
`hardware-configuration.nix`, so its initrd lacks virtio block drivers and stage-1
times out on `/dev/disk/by-label/nixos`. Use the `build.vm` runner above instead, or
add `(modulesPath + "/profiles/qemu-guest.nix")` to the host to fix the standalone
image.

## Booting the live ISO in a throwaway QEMU VM

```bash
nix build .#nixosConfigurations.iso.config.system.build.isoImage   # output: ./result/iso/*.iso

nix run nixpkgs#qemu -- -enable-kvm -m 4096 -smp 4 \
  -device virtio-vga-gl -display gtk,gl=on \
  -audiodev pipewire,id=snd0 -device ich9-intel-hda -device hda-duplex,audiodev=snd0 \
  -cdrom result/iso/*.iso
```
