# Dziennik: ssh

Feature konfiguracji klienta SSH przez HM (`programs.ssh`) z matchBlocks i ssh-agent.

## Gotchas

**2026-06-26** — HM generuje `~/.ssh/config` z `programs.ssh.matchBlocks`. Plik nie jest tworzony, jeśli `home-manager-wiktor.service` nie dobiegnie końca pomyślnie.
Próba czeka na `home-manager-wiktor.service` przed asercją `test -f ~/.ssh/config`.

**2026-06-26** — Deprecation warnings od HM: `matchBlocks.<host>.extraOptions` jest przestarzałe na rzecz `programs.ssh.settings.<host>`. Nie blokuje buildu ani testu — tylko ostrzeżenie przy ewaluacji. Migracja do nowego formatu odkłada się do refaktoru feature'a.
