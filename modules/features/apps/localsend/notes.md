# localsend — Dziennik

2026-06-26: Dodano featureMeta + Próbę.

Objaw: `command -v localsend` zwraca „not found" mimo zainstalowanego pakietu.
Przyczyna: Upstream Flutter build nadaje binarce nazwę `localsend_app`, nie `localsend`.
Fix: Próba asertuje `command -v localsend_app`.
