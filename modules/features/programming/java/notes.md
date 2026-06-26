# Dziennik — java

## 2026-06-26

Objaw: `gradle --version` w Próbie uruchamia demona i może przekroczyć timeout VM.
Przyczyna: Gradle przy pierwszym wywołaniu próbuje pobrać wrappera lub init-script z sieci.
Fix: W środowisku VM sieć jest dostępna, ale Gradle działa offline, bo nie ma konfiguracji projektu — samo `gradle --version` nie uruchamia buildu, jedynie weryfikuje instalację; timeout VM (zwykle 5 min) jest wystarczający.
