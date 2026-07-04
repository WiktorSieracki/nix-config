# Dziennik — cachix

## 2026-07-04

- Cache `wiktor-nixos` (publiczny, darmowy tier = 5 GB) istniał już wcześniej:
  pushują do niego workflowy CI (`iso.yaml`, `proba.yaml`) przez
  `cachix/cachix-action` z tokenem w GitHub secrets (`CACHIX_AUTH_TOKEN`).
  Ten feature dodaje stronę maszyn: pull (substituter) + push (`cache-push`).
- `cache-push` pushuje **tylko ścieżki bez podpisu** binary cache'a — czyli
  dokładnie to, co maszyna zbudowała sama (unfree repaki vscode/cursor,
  overridnięte drv). Ścieżki podpisane przez cache.nixos.org / numtide /
  agent-of-empires.cachix.org zawsze da się ściągnąć ponownie, a pchanie ich
  przepaliłoby darmowe 5 GB.
- Token do zapisu: `sops secrets.yaml` → klucz `cachixAuthToken` (właściciel
  wiktor, ląduje w `/run/secrets/cachixAuthToken`). W repo siedzi placeholder
  `CHANGE_ME`, który skrypt odrzuca z czytelnym komunikatem. Po podmianie
  tokena trzeba re-aktywować system (`nh os test`), żeby sops-nix odświeżył
  `/run/secrets`.
- Uwaga: cache jest **publiczny** — wypchnięte tam przepakowane binarki
  unfree (vscode/cursor) może pobrać każdy, kto zna nazwę. Świadoma decyzja;
  gdyby to przeszkadzało, cachix ma płatne cache prywatne.
