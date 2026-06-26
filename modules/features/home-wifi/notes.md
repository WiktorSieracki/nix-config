# home-wifi — Dziennik

## 2026-06-26 — runtimeUntestable; render profilu NM porzucony

Analogicznie do [[eduroam]]: bez prawdziwego klucza SOPS profil NetworkManagera
nie powstaje w VM, a feature i tak potrzebuje realnego AP. `runtimeUntestable =
true`, Próba boot-only (stub zeruje sekrety + pod-opcje
`ensureProfiles.environmentFiles`/`.profiles`; asercja: boot + `nmcli`).

Drobiazgi zaobserwowane po drodze (gdyby kiedyś wracać do renderu w VM):
- NM nazywa plik profilu wg `connection.id`, nie wg klucza atrybutu.
- WPA-PSK wymaga hasła 8–63 znaków — krótszy fałszywy PSK jest odrzucany i plik
  profilu nie powstaje (eduroam używa `wpa-eap`, bez tego limitu).
