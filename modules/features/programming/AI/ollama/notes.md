# ollama — Dziennik

Local LLM server (`services.ollama`) so agents like `omp` (see `llm-agents`) can
run models on the desktop's NVIDIA GPU.

## Knowledge

- **`acceleration` option was removed upstream.** It's now a
  `mkRemovedOptionModule` that errors and tells you to set
  `services.ollama.package` instead. nixpkgs variants: `ollama-cuda` (NVIDIA),
  `ollama-cpu`, `ollama-rocm` (AMD), `ollama-vulkan`. **We don't use any of
  them** — see the 2026-06-30 entries; we ship upstream's prebuilt 0.30.11 via
  `autoPatchelfHook` instead (`services.ollama.package = mkOllamaBin pkgs`). The
  prebuilt bundles CPU+CUDA+Vulkan backends, so it covers both desktop (GPU) and
  the VM Próba (CPU) with one package.
- **Listens on `127.0.0.1:11434` by default**, firewall left closed — for local
  clients only. To expose it (e.g. another machine over tailscale), set
  `services.ollama.host` / `port` and `openFirewall = true`.
- The NixOS module both starts `ollama.service` (`wantedBy = multi-user.target`)
  and puts the `ollama` CLI on PATH via `environment.systemPackages`.
- Models are **not** preloaded. Pull them at runtime with `ollama pull <model>`
  (or declare `services.ollama.loadModels = [ ... ]` to fetch on service start).
- CUDA acceleration needs the real GPU, so it can't be exercised in the VM — the
  Próba swaps in `ollama-cpu` and only asserts the daemon/API/CLI work.

## 2026-06-30 — próba bumpu do v0.31.0 (nieudana)

**Objaw:** `ollama run <model>` zwraca `Error: pull model manifest: 412: The model
you are attempting to pull requires a newer version of Ollama`. nixpkgs ma 0.30.7
(także HEAD nixos-unstable), a niektóre modele na ollama.com wymagają nowszego
serwera.

**Przyczyna:** próba podbicia do `v0.31.0` przez `overrideAttrs` (version + src +
vendorHash) wywala się w `patchPhase` go-modules: `error: patch failed:
tools/mtmd/clip.cpp:2822 ... failed to apply 001-llama-cpp-hooks.patch`. nixpkgs
przypina własne źródło llama.cpp (`llamaCppSrc`, tag `b9509`) i nakłada na nie
patch dopasowany do 0.30.7 — w 0.31.0 zmienił się ten plik, więc patch nie pasuje.

**Fix:** brak czystego ze źródeł. Żeby zbudować 0.31.0 trzeba by jednocześnie
podbić `llamaCppSrc` i zregenerować `001-llama-cpp-hooks.patch` — czyli powtórzyć
packaging nixpkgs. abysssol/ollama-flake nie pomaga (przypięte do 0.5.1 = downgrade).
**Co więcej:** `v0.31.0` to tylko tag w gicie — **nie ma opublikowanego release'u
z binarkami** (GitHub API zwraca 404). Najnowszy realnie wydany to **v0.30.11**.

## 2026-06-30 — patch nie pasuje też do 0.30.11; rozwiązanie: prebuilt + autoPatchelf

**Objaw:** override do **0.30.11** (najnowszy wydany) ze źródeł pada tak samo:
`failed to apply 001-llama-cpp-hooks.patch` (`tools/mtmd/clip.cpp:2822`). Czyli
nixpkgsowy patch nie pasuje do **żadnej** wersji nowszej niż 0.30.7 — wbudowany
llama.cpp ruszył już między 0.30.7 a 0.30.11.

**Rozwiązanie (obecny stan feature'a):** pakujemy **oficjalną binarkę
`ollama-linux-amd64.tar.zst` z release v0.30.11** przez `autoPatchelfHook`
(`mkOllamaBin`). Tarball niesie własne ggml/llama.cpp + CUDA + Vulkan, więc nie
budujemy nic ze źródeł i omijamy patch. Potrzebne klocki, których szukał
auto-patchelf: `vulkan-loader` (→ `libvulkan.so.1`) w `buildInputs`,
`stdenv.cc.cc.lib` (libstdc++), a `libcuda.so.1` / `libnvidia-ml.so.1` idą do
`autoPatchelfIgnoreMissingDeps` i są domykane w runtime przez `autoAddDriverRunpath`
(stąd GPU działa, gdy jest sterownik, a bez GPU leci CPU). **Weryfikacja:** binarka
odpala się natywnie bez `steam-run` (`$out/bin/ollama --version` → client 0.30.11).

**Aktualizacja w przyszłości:** podbij `ollamaVersion` + `hash` (SRI) tarballa
(`nix hash file ollama-linux-amd64.tar.zst` po pobraniu z nowego release'u). Gdy
nixpkgs w końcu spakuje nowsze ollama z poprawnym patchem, można wrócić do
`services.ollama.package = pkgs.ollama-cuda` i skasować `mkOllamaBin`.
