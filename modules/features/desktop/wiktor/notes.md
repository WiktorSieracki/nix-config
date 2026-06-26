# Dziennik: wiktor

*Ostatnia aktualizacja: 2026-06-26*

## Gotcha: home-manager-wiktor.service musi wystartować przed asercjami HM

**Objaw**: testy asercji sprawdzające katalog domowy lub HM-zależne programy
failują, mimo że `multi-user.target` jest osiągnięty.  
**Przyczyna**: `home-manager-wiktor.service` jest osobnym systemd unit,
który może nie zakończyć się przed `multi-user.target`.  
**Fix**: w testScript czekaj jawnie na
`machine.wait_for_unit("home-manager-wiktor.service")` po
`machine.wait_for_unit("multi-user.target")`.
