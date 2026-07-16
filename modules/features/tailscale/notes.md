# feature notes: tailscale

The Tailscale VPN feature — the `tailscaled` systemd service with `useRoutingFeatures = "client"`.

## Gotchas

**2026-06-26** — `tailscaled.service` starts in the VM test, but needs access to the Tailscale control-plane (`login.tailscale.com`) to join the network.
Symptom: `tailscale up` in the VM hangs without an auth key.
Cause: The feature test only checks that the unit is active (not that the network is established) — a deliberate Tier 1 limitation.
Fix: An e2e test (Tier 2) should verify actual connectivity using `TS_AUTHKEY`.
