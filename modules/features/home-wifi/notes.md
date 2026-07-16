# home-wifi — feature notes

## 2026-06-26 — runtimeUntestable; rendering the NM profile abandoned

Analogous to [[eduroam]]: without a real SOPS key the NetworkManager profile isn't
created in a VM, and the feature needs a real AP anyway. `runtimeUntestable =
true`, boot-only feature test (the stub zeroes the secrets + the sub-options
`ensureProfiles.environmentFiles`/`.profiles`; assertion: boot + `nmcli`).

Small things observed along the way (in case rendering in a VM is ever revisited):
- NM names the profile file by `connection.id`, not by the attribute key.
- WPA-PSK requires an 8–63 character password — a shorter fake PSK is rejected and
  the profile file isn't created (eduroam uses `wpa-eap`, without that limit).
