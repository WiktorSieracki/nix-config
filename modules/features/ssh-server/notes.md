# Dziennik: ssh-server

Feature serwera OpenSSH z wyłączoną autoryzacją hasłem i kluczem publicznym dla użytkownika wiktor.

## Gotchas

**2026-06-26** — Na NixOS `services.openssh.enable = true` tworzy unit `sshd.service` (nie `ssh.service`).
Próba asertuje `sshd.service` — jest to prawidłowa nazwa na NixOS (w przeciwieństwie do Debiana, gdzie może być `ssh.service`).

**2026-06-26** — `PermitRootLogin = "no"` i `PasswordAuthentication = false` powodują, że VM z Próby nie może być debugowana przez hasło roota. W razie potrzeby debugowania dodać klucz testowy do `extraNixosModules`.
