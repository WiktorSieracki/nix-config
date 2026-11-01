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

## The live server (2026-11-01)

Hetzner Cloud project `nix-vps`, server `vps-nixos`: **cx23** (2 vCPU / 4 GB /
40 GB) in **hel1**, IPv4 `89.167.89.171`, IPv6 `2a01:4f9:c015:fc8e::1`. CX33
was not orderable in any location that day (`hcloud server-type describe
cx33`), so the host runs on a cx23 with zram; `hcloud server change-type
vps-nixos cx33` (server powered off) once it's back. Booted BIOS, disk
`/dev/sda`, installed by nixos-anywhere from an ubuntu-24.04 image.

## Install (nixos-anywhere)

1. Order the server with any Linux image and your SSH key; boot it into the
   rescue system (Hetzner: Rescue → linux64), or just use the stock image —
   nixos-anywhere kexecs into a NixOS installer either way.
2. The VPS has its **own** key: sops decrypts with its ssh host key
   (`hosts/vps-nixos/sops.nix`), never wiktor's `~/.ssh/id_ed25519`, and
   only `secrets-vps.yaml` is encrypted to it. Its private half lives
   encrypted in that file as `vpsHostKey`; stage it in a tmpfs dir:

   ```bash
   tmp=$(mktemp -d "$XDG_RUNTIME_DIR/vps.XXXX")
   install -d -m 755 "$tmp/etc/ssh"
   (umask 077; sops -d --extract '["vpsHostKey"]' secrets-vps.yaml > "$tmp/etc/ssh/ssh_host_ed25519_key")
   ssh-keygen -y -f "$tmp/etc/ssh/ssh_host_ed25519_key" > "$tmp/etc/ssh/ssh_host_ed25519_key.pub"
   ```

3. Install (formats the disk from `disko.nix`):

   ```bash
   nix run github:nix-community/nixos-anywhere -- \
     --flake .#vpsNixos --extra-files "$tmp" root@<ip>
   rm -rf "$tmp"
   ```

   Its public host key is known in advance (for `known_hosts`):
   `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKKVozCO3BZQzHQM+bu0lpJvyaTYWQaccYGCwpc1I44d`.

4. `ssh wiktor@<ip>` → `sudo tailscale up --operator=wiktor` (opens a login
   URL). The `--operator` matters: a bare `tailscale up` resets the operator
   that the `tailscale` feature sets via `tailscaled-set.service`, and
   t3code's `tailscale serve` then fails with `permission-denied` — while the
   unit stays `active`, it just logs "Failed to configure Tailscale Serve"
   (measured 2026-11-01). Fix after the fact:
   `sudo systemctl restart tailscaled-set; systemctl --user restart t3code`.
   Then `tailscale serve status` shows `https://vps-nixos.<tailnet>.ts.net`; `journalctl --user -u t3code`
   prints the pairing URL/token (`t3 pair` mints a new one).
5. Give the VPS its own GitHub identity — again never your personal key:
   `ssh-keygen -t ed25519 -C wiktor@vpsNixos` on the box, then add the
   `.pub` to GitHub (`gh ssh-key add`, or a per-repo deploy key for tighter
   scope). Revoke it on GitHub if the VPS is ever compromised.
6. Claude Code needs no login on the box: it runs on the long-lived token in
   `secrets-vps.yaml` (`claudeCodeOauthToken` → `CLAUDE_CODE_OAUTH_TOKEN`,
   `claude-token.nix`). `claude auth login` over SSH kept rejecting the
   pasted code. Renew yearly: `claude setup-token` **on the desktop**, then
   `sops secrets-vps.yaml` and switch. Google sign-in from a datacenter IP often hits extra
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

## Secrets

`secrets-vps.yaml` (recipients: wiktor + the VPS host key, `.sops.yaml`)
holds `studentEmail`, `personalEmail` (git identity), `cachixAuthToken`,
`firecrawlApiKey`, `openrouterApiKey`, `claudeCodeOauthToken` (exported as `FIRECRAWL_API_KEY` /
`OPENROUTER_API_KEY` by the `firecrawl-api` / `openrouter-api` features) and
`vpsHostKey`. A feature added here that declares a new `sops.secrets.<x>`
needs `<x>` copied into this file (`sops secrets-vps.yaml`), or activation
fails on the missing key.

The Firecrawl and OpenRouter keys started as copies of the laptop's. To give
the VPS its own (so a leak there can be revoked without touching the other
machines), create new keys at firecrawl.dev/app/api-keys and
openrouter.ai/settings/keys, replace them with `sops secrets-vps.yaml`, and
switch. Rotating the host key: generate a new one, swap the
`&vpsNixos` age key (`ssh-to-age`), `sops updatekeys secrets-vps.yaml`, replace
`vpsHostKey`, put the key on the box and switch.
