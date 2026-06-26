# eduroam — Dziennik

## 2026-06-26 — ukryta zależność od `sops`

eduroam deklaruje własne `sops.secrets`, ale klucz (`age.sshKeyPaths`) i
`defaultSopsFile` daje dopiero feature `sops` → `requires = ["sops"]`. Patrz też
folderyzacja [[sops]] (jego względna ścieżka do `secrets.yaml` wymagała korekty).

## 2026-06-26 — runtimeUntestable; render profilu NM w VM porzucony

**Objaw/Przyczyna:** próba wyrenderowania profilu NetworkManagera w VM jest
krucha — sops-nix i tak wymaga prawdziwego klucza do renderu template'u
(`sshKeyPaths=[]` → brak env → profil się nie tworzy). A eduroam i tak wymaga
realnej sieci eduroam + RADIUS.

**Fix:** `runtimeUntestable = true`, Próba boot-only. Stub `lib.mkForce` zeruje
sekrety/template'y ORAZ **pod-opcje** `ensureProfiles.environmentFiles`/`.profiles`
(mkForce na rodzicu `ensureProfiles` nie wystarcza — feature ustawia pod-ścieżki,
które dalej się ewaluują i odwołują do skasowanego template'u → `attribute
'eduroam-env' missing`). Asercja: system wstaje + `nmcli` na PATH.
