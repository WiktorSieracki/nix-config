# Dziennik — docker

## 2026-06-26

Objaw: `virtualisation.docker.rootless` instaluje demona jako systemd *user* service, nie system service. `machine.wait_for_unit("docker.service")` w nixosTest failuje, bo nie ma sesji użytkownika.
Przyczyna: Rootless Docker działa w kontekście użytkownika (`systemctl --user`). nixosTest nie startuje sesji użytkownika automatycznie.
Fix: Próba ograniczona do `docker --version` (CLI jest dostępne system-wide). Jeśli w przyszłości potrzebny test demona, dodać maszynę z autologinem i sprawdzić `su - <user> -c 'systemctl --user status docker.service'` po zalogowaniu.

Objaw: `hardware.graphics.enable32Bit = true` powoduje budowanie 32-bitowych bibliotek Mesa w nixosTest (niepotrzebne, wolne).
Przyczyna: Opcja istnieje dla obsługi NVIDIA/gier, nie jest wymagana przez dockera CLI.
Fix: Próba nadpisuje tę opcję `lib.mkForce false` przez `extraNixosModules`.
