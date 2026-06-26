# Dziennik — cpp

## 2026-06-26

Objaw: `clang` pochodzi z paczki `clang` nixpkgs, ale `clang-tools` dostarcza oddzielne narzędzia (`clang-format`, `clang-tidy`). Nie ma sensu testować `clang-tidy --version` w Próbie, bo zależy od obecności bazy LLVM — `clang --version` wystarczy jako smoke.
Przyczyna: Feature jest wyłącznie HM (home.packages), więc wymaga `requires = ["wiktor"]` — bez użytkownika wiktor HM nie jest dołączony i paczki nie trafiają na PATH żadnego użytkownika.
Fix: Próba czeka na `home-manager-wiktor.service` przed asercjami `su - wiktor -c '...'`.
