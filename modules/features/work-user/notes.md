# work-user — Dziennik

2026-07-04: Feature utworzony — odizolowane konto `work` (Slack, VS Code,
Google Chrome przez `users.users.work.packages`) do rozdzielenia pracy od
konta prywatnego.

Granice izolacji (czego test NIE dowodzi): pakiety z
`environment.systemPackages` innych feature'ów (firefox, discord, …) są
systemowe, więc `work` technicznie może je uruchomić — per-user packages
izolują tylko PATH/launcher, nie wykonywalność ze store. Pełna blokada
wymagałaby MAC (AppArmor/SELinux) i nie jest celem tego feature'a.

`initialPassword = "work"` działa tylko przy pierwszym utworzeniu konta —
po pierwszym `nh os switch` zmień hasło: `sudo passwd work`.
