# blender — feature notes

2026-10-04: Added as a per-user feature (wiktor on desktopNixos).

Uses the binary-cached `pkgs.blender` (no CUDA). Cycles GPU rendering on the
NVIDIA card would need `blender.override { cudaSupport = true; }`, which is not
in the public cache and compiles from source.
