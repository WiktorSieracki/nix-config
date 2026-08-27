---
name: nh-deploy
description: Apply this NixOS config with nh — the local test→verify→switch loop, and remote SSH flows in both directions (--target-host deploys desktop → laptop; --build-host switches the laptop while the desktop builds). Use when the user wants to apply/rebuild the config, deploy to the laptop, offload a build to the desktop, or a remote deploy fails.
---

# /nh-deploy

`nh` ([nix-community/nh](https://github.com/nix-community/nh)) is this flake's
deploy tool. `NH_FLAKE` already points at the repo, so `nh os …` works from any
directory. Flakes only evaluate git-tracked files — `git add` new files first.

## Local apply (this machine)

1. `nh os test` — build + activate, no boot entry. Runs without a sudo prompt
   (wheel is NOPASSWD).
2. Verify the affected app/script actually works — activation succeeding is not
   the bar.
3. `nh os switch` — activate *and* make it the boot default.

`nh os switch --dry` previews the diff without applying; `-u` also updates
flake inputs.

## Remote deploy: build on the desktop, activate on the laptop

The desktop builds the laptop's closure, copies it over SSH, and activates it
remotely — the laptop needs no checkout of the repo and builds nothing.

1. Reachability: `ssh laptop true`. The alias comes from `ssh-personal-hosts`
   and resolves over Tailscale; if it hangs, check `tailscale status` on both
   ends.
2. `nh os test -H laptopNixos --target-host laptop` — safe activation, no boot
   entry.
3. Verify over SSH that the deployed change works (`ssh laptop -- <command>`).
4. `nh os switch -H laptopNixos --target-host laptop` — make it the laptop's
   boot default.

- `-H laptopNixos` selects `nixosConfigurations.laptopNixos`. nh would infer it
  from the target's hostname, but pass it explicitly so the deploy doesn't
  depend on what the target currently calls itself.
- The direction is symmetric: from the laptop,
  `nh os switch -H desktopNixos --target-host desktop`.

## Remote build: run on the laptop, build on the desktop

`--build-host` is the mirror image of `--target-host`: activate *here*, build
*there*. Use it when sitting at the laptop and its own build would be too slow.

1. Update the checkout on the laptop (`git pull`) — unlike `--target-host`,
   the flake is evaluated **locally**, so the laptop needs the current repo.
2. Reachability: `ssh desktop true`.
3. `nh os test --build-host desktop` — derivations are copied to the desktop,
   built there, the results copied back and activated on the laptop. No `-H`
   needed: it defaults to the local hostname (`laptopNixos`).
4. Verify, then `nh os switch --build-host desktop`.

The trusted-users requirement applies here too, just on the laptop's side: the
paths copied back from the desktop are unsigned, and the local daemon accepts
them only from a trusted user (@wheel).

## Failure modes

- **`…lacks a signature by a trusted key`** — the receiving nix daemon rejects
  the locally-built, unsigned store paths. The target must have
  `nix.settings.trusted-users = ["root" "@wheel"]` (set in the `nix` feature
  since 39bf69f). If the target predates that commit, it can't be fixed
  remotely: apply the config once locally on the target, then deploys work.
- **Activation stalls waiting for a password** — remote elevation detection
  failed; retry with `-e passwordless` (tells nh the target's sudo is
  NOPASSWD, which this fleet's wheel group is).
- **Eval can't see a file that exists** — it's untracked; `git add` it.

## Housekeeping

- `nh clean all --keep 3 --keep-since 7d` — GC old generations + stale gcroots.
  Cleans only the machine it runs on, so run it on each host (locally or via
  `ssh laptop`).
- `nh search <term>` — quick nixpkgs package search (for option lookups use
  `manix` or the /search-nix skill).
