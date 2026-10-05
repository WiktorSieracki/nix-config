# teams-for-linux — feature notes

2026-06-26: Added featureMeta + a feature test.

No known gotchas. The `teams-for-linux` binary is available as an open-source wrapper (not the official MS Teams client) and doesn't require allowUnfree.

2026-10-05: Keybind moved `Mod+T` → `Mod+M`; `todoist` took `Mod+T`. `flake.niriBinds`
is folded globally in `niri.nix`, so a chord claimed by two features resolves by
attribute order rather than by which host enables what — one owner per chord.
