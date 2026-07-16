{...}: let
  ollamaVersion = "0.30.11";

  # Upstream's prebuilt release, autoPatchelf'd into the Nix store.
  #
  # Why not build from source via nixpkgs? nixpkgs ships 0.30.7 and pins its own
  # llama.cpp + a `001-llama-cpp-hooks.patch` cut against it. Every newer ollama
  # (0.30.8+, incl. the newest *released* 0.30.11, and the source-only v0.31.0
  # tag) bumped the bundled llama.cpp, so that patch no longer applies and a
  # plain overrideAttrs fails in patchPhase. Regenerating the patch per release
  # is exactly the packaging work we want to avoid.
  #
  # The official tarball already ships its own ggml/llama.cpp + CUDA + Vulkan
  # libs, so we just fix the ELF interpreter/rpath (autoPatchelfHook) and stamp
  # the NVIDIA driver runpath on it (autoAddDriverRunpath) so the bundled CUDA
  # libs find libcuda at runtime where a GPU+driver exist, and fall back to the
  # bundled CPU ggml backends where they don't (e.g. the VM Próba). See notes.md.
  mkOllamaBin = pkgs:
    pkgs.stdenv.mkDerivation (finalAttrs: {
      pname = "ollama-bin";
      version = ollamaVersion;
      src = pkgs.fetchurl {
        url = "https://github.com/ollama/ollama/releases/download/v${finalAttrs.version}/ollama-linux-amd64.tar.zst";
        hash = "sha256-EdyJtsaPE2+F7xDgCVdTD/q2HDXyJ2ltv4oRFptH8WU=";
      };
      nativeBuildInputs = [pkgs.zstd pkgs.autoPatchelfHook pkgs.autoAddDriverRunpath];
      buildInputs = [pkgs.stdenv.cc.cc.lib pkgs.vulkan-loader];
      # Resolved at runtime from the NVIDIA driver via autoAddDriverRunpath; not
      # present at build time (and absent entirely on a GPU-less host/VM).
      autoPatchelfIgnoreMissingDeps = ["libcuda.so.1" "libnvidia-ml.so.1"];
      unpackPhase = ''
        runHook preUnpack
        mkdir -p source
        tar --use-compress-program=unzstd -xf "$src" -C source
        runHook postUnpack
      '';
      installPhase = ''
        runHook preInstall
        mkdir -p "$out"
        cp -r source/bin source/lib "$out/"
        runHook postInstall
      '';
      meta.mainProgram = "ollama";
    });
in {
  flake.modules.nixos.ollama = {pkgs, ...}: {
    services.ollama = {
      enable = true;
      # Prebuilt v0.30.11 (see above). The systemd unit also puts this `ollama`
      # CLI on PATH. Daemon listens on 127.0.0.1:11434 (local only, firewall
      # closed) — local clients like `omp` (llm-agents) talk to it over HTTP.
      package = mkOllamaBin pkgs;
    };
  };

  # Self-contained: the prebuilt bundles its own CPU + CUDA + Vulkan backends, so
  # the feature has no hard deps. GPU acceleration is opportunistic — it kicks in
  # where the NVIDIA driver is present (desktopNixos enables `nvidia`), and falls
  # back to CPU otherwise. kind=service: daemon + API + CLI are testable in a VM.
  flake.featureMeta.ollama = {
    requires = [];
    kind = "service";
  };

  # Próba: prove the daemon comes up, the HTTP API listens, the CLI reaches it,
  # and the server reports the bumped version (guards the prebuilt override). No
  # GPU in the VM — the bundled CPU ggml backends carry it.
  flake.featureTests.ollama = {
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("ollama.service")
      machine.wait_for_open_port(11434)
      machine.succeed("ollama list")
      machine.succeed("ollama --version 2>&1 | grep -q 0.30.11")
    '';
  };
}
