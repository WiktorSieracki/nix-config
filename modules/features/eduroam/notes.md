# eduroam — feature notes

## 2026-06-26 — hidden dependency on `sops`

eduroam declares its own `sops.secrets`, but the key (`age.sshKeyPaths`) and
`defaultSopsFile` are provided only by the `sops` feature → `requires = ["sops"]`.
See also the folderization of [[sops]] (its relative path to `secrets.yaml`
needed a fix).

## 2026-06-26 — runtimeUntestable; rendering the NM profile in a VM abandoned

**Symptom/Cause:** trying to render a NetworkManager profile in a VM is brittle —
sops-nix needs a real key to render the template anyway (`sshKeyPaths=[]` → no env
→ the profile isn't created). And eduroam needs a real eduroam network + RADIUS
regardless.

**Fix:** `runtimeUntestable = true`, boot-only feature test. The `lib.mkForce`
stub zeroes the secrets/templates AND the **sub-options**
`ensureProfiles.environmentFiles`/`.profiles` (mkForce on the parent
`ensureProfiles` isn't enough — the feature sets sub-paths that still evaluate and
reference the deleted template → `attribute 'eduroam-env' missing`). Assertion:
the system comes up + `nmcli` on PATH.
