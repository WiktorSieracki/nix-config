# feature notes — cachix

## 2026-07-04

- The `wiktor-nixos` cache (public, free tier = 5 GB) already existed earlier:
  the CI workflows (`iso.yaml`, `feature-tests.yaml`) push to it via
  `cachix/cachix-action` with a token in GitHub secrets (`CACHIX_AUTH_TOKEN`).
  This feature adds the machine side: pull (substituter) + push (`cache-push`).
- `cache-push` pushes **only unsigned paths** of the binary cache — i.e. exactly
  what the machine built itself (unfree vscode/cursor repacks, overridden drvs).
  Paths signed by cache.nixos.org / numtide / agent-of-empires.cachix.org can
  always be re-fetched, and pushing them would burn the free 5 GB.
- Write token: `sops secrets.yaml` → key `cachixAuthToken` (owner wiktor, lands
  in `/run/secrets/cachixAuthToken`). The repo holds a `CHANGE_ME` placeholder
  which the script rejects with a readable message. After swapping the token you
  must re-activate the system (`nh os test`) so sops-nix refreshes `/run/secrets`.
- Note: the cache is **public** — repacked unfree binaries pushed there
  (vscode/cursor) can be pulled by anyone who knows the name. A conscious
  decision; if it were a problem, cachix has paid private caches.
