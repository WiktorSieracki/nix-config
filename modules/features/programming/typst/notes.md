# Dziennik — typst

## 2026-06-26

Objaw: `typst-live` to narzędzie live-preview (prawdopodobnie wrapper uruchamiający serwer HTTP). Nie testujemy go w Próbie, bo wymaga pliku `.typ` i przeglądarki.
Przyczyna: Binarka `tinymist` to LSP server dla typst — nie ma flagi `--version`; uruchamia się z argumentem lub bez, ale przy braku argumentów może zawiesić się czekając na stdio.
Fix: Próba ograniczona do `typst --version` i `typstyle --version` — one zawsze zwracają exit 0 bez efektów ubocznych.
