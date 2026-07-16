# ollama — feature notes

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
  the VM feature test (CPU) with one package.
- **Listens on `127.0.0.1:11434` by default**, firewall left closed — for local
  clients only. To expose it (e.g. another machine over tailscale), set
  `services.ollama.host` / `port` and `openFirewall = true`.
- The NixOS module both starts `ollama.service` (`wantedBy = multi-user.target`)
  and puts the `ollama` CLI on PATH via `environment.systemPackages`.
- Models are **not** preloaded. Pull them at runtime with `ollama pull <model>`
  (or declare `services.ollama.loadModels = [ ... ]` to fetch on service start).
- CUDA acceleration needs the real GPU, so it can't be exercised in the VM — the
  feature test swaps in `ollama-cpu` and only asserts the daemon/API/CLI work.

## 2026-06-30 — attempted bump to v0.31.0 (failed)

**Symptom:** `ollama run <model>` returns `Error: pull model manifest: 412: The
model you are attempting to pull requires a newer version of Ollama`. nixpkgs has
0.30.7 (also on HEAD nixos-unstable), and some models on ollama.com need a newer
server.

**Cause:** bumping to `v0.31.0` via `overrideAttrs` (version + src + vendorHash)
fails in the go-modules `patchPhase`: `error: patch failed:
tools/mtmd/clip.cpp:2822 ... failed to apply 001-llama-cpp-hooks.patch`. nixpkgs
pins its own llama.cpp source (`llamaCppSrc`, tag `b9509`) and applies a patch
tuned to 0.30.7 — in 0.31.0 that file changed, so the patch doesn't apply.

**Fix:** none cleanly from source. Building 0.31.0 would require simultaneously
bumping `llamaCppSrc` and regenerating `001-llama-cpp-hooks.patch` — i.e.
repeating the nixpkgs packaging. abysssol/ollama-flake doesn't help (pinned to
0.5.1 = a downgrade). **What's more:** `v0.31.0` is only a git tag — **there is no
published release with binaries** (the GitHub API returns 404). The latest
actually released is **v0.30.11**.

## 2026-06-30 — the patch doesn't apply to 0.30.11 either; solution: prebuilt + autoPatchelf

**Symptom:** an override to **0.30.11** (the latest released) from source fails the
same way: `failed to apply 001-llama-cpp-hooks.patch` (`tools/mtmd/clip.cpp:2822`).
So the nixpkgs patch doesn't apply to **any** version newer than 0.30.7 — the
bundled llama.cpp already moved between 0.30.7 and 0.30.11.

**Solution (current state of the feature):** we package the **official binary
`ollama-linux-amd64.tar.zst` from release v0.30.11** via `autoPatchelfHook`
(`mkOllamaBin`). The tarball carries its own ggml/llama.cpp + CUDA + Vulkan, so we
build nothing from source and skip the patch. The pieces auto-patchelf was looking
for: `vulkan-loader` (→ `libvulkan.so.1`) in `buildInputs`, `stdenv.cc.cc.lib`
(libstdc++), while `libcuda.so.1` / `libnvidia-ml.so.1` go to
`autoPatchelfIgnoreMissingDeps` and are resolved at runtime by
`autoAddDriverRunpath` (hence GPU works when a driver is present, and without a GPU
it falls back to CPU). **Verification:** the binary runs natively without
`steam-run` (`$out/bin/ollama --version` → client 0.30.11).

**Future updates:** bump `ollamaVersion` + the tarball `hash` (SRI)
(`nix hash file ollama-linux-amd64.tar.zst` after downloading from a new release).
Once nixpkgs finally packages a newer ollama with a correct patch, you can go back
to `services.ollama.package = pkgs.ollama-cuda` and delete `mkOllamaBin`.
