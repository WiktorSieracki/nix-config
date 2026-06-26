# Dziennik: tailscale

Feature VPN Tailscale — systemd service `tailscaled` z `useRoutingFeatures = "client"`.

## Gotchas

**2026-06-26** — `tailscaled.service` startuje w VM testu, ale wymaga dostępu do control-plane Tailscale (`login.tailscale.com`) żeby połączyć się z siecią.
Objaw: `tailscale up` w VM zawiesza się bez klucza uwierzytelniającego.
Przyczyna: Próba sprawdza tylko, że unit jest aktywny (nie że sieć jest nawiązana) — to celowe ograniczenie Tier 1.
Fix: Test e2e (Tier 2) powinien weryfikować faktyczną łączność z użyciem `TS_AUTHKEY`.
