# vpsNixos — notes

A headless cloud VPS: the T3 Code server (`t3code-server`), the coding agents,
and the repos. No desktop. Reached only over the tailnet (t3code via Tailscale
Serve) and SSH on 22.

## Provider choice (2026-11-01)

Sized for Hetzner Cloud **CX33** (4 vCPU / 8 GB / 80 GB, €8.49 + €0.50 IPv4
net, hourly). Upgrade in place to CX43 (8 / 16 / 160) if builds get tight.
OVH VPS-2 in Warsaw (4 / 8 / 75, 30.77 PLN net, 12 months upfront) is the
cheaper alternative closer to home. Both are KVM with the disk at `/dev/sda`,
which is what `disko.nix` assumes; check `lsblk` in the rescue system first —
if the provider exposes `/dev/vda`, change both `disko.nix` and
`boot.loader.grub.devices`.

## Install (nixos-anywhere)

1. Order the server with any Linux image and your SSH key; boot it into the
   rescue system (Hetzner: Rescue → linux64), or just use the stock image —
   nixos-anywhere kexecs into a NixOS installer either way.
2. The `sops` feature decrypts with `/home/wiktor/.ssh/id_ed25519`, so that
   key has to exist on the machine before the first activation. Stage it:

   ```bash
   tmp=$(mktemp -d)
   install -d -m 700 -o 1000 -g 100 "$tmp/home/wiktor/.ssh"
   install -m 600 ~/.ssh/id_ed25519 "$tmp/home/wiktor/.ssh/"
   install -m 644 ~/.ssh/id_ed25519.pub "$tmp/home/wiktor/.ssh/"
   ```

3. Install (formats the disk from `disko.nix`):

   ```bash
   nix run github:nix-community/nixos-anywhere -- \
     --flake .#vpsNixos --extra-files "$tmp" --chown /home/wiktor 1000:100 \
     root@<ip>
   rm -rf "$tmp"
   ```

4. `ssh wiktor@<ip>` → `sudo tailscale up` (opens a login URL). Once the node
   is on the tailnet, `t3code.service` stops crash-looping on
   `tailscale serve` and publishes itself; `journalctl --user -u t3code`
   prints the pairing URL/token (`t3 pair` mints a new one).
5. Log in to the agents on the box: `claude` (prints an OAuth URL to open on
   any device). Google sign-in from a datacenter IP often hits extra
   verification — route through the desktop as a Tailscale exit node for that.

## Updating

```bash
nh os switch -H vpsNixos --target-host <tailscale-name-or-ip>
```

Builds locally, copies the closure, activates remotely.

## Testing locally

`nix build .#nixosConfigurations.vpsNixos.config.system.build.vmWithDisko`
boots the exact disk layout in QEMU. sops-backed secrets fail there (no key),
everything else comes up (verified 2026-11-01: no failed units, `t3code` answers
on 127.0.0.1:3773 and waits for `tailscale up`). It boots the kernel directly,
so the GRUB BIOS/ESP install is only exercised by the real first boot — if the
VPS doesn't come up, check the provider's console for the GRUB stage first.
