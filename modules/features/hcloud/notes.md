# hcloud — feature notes

## 2026-11-01 — the `datacenter` API is gone; availability is per location

**Symptom:** `hcloud datacenter list -o json` fails with
`API functionality was removed (deprecated_api_endpoint)`.

**Cause:** Hetzner moved server-type availability from datacenters to
locations. It now sits on the server type itself.

**Fix:** ask per server type:

```bash
hcloud server-type describe cx33 -o json | jq '.locations[] | {name, available}'
```

`available: true` is not a guarantee either: during the 2026 hardware
shortage (status.hetzner.com, "Limited availability of cloud instances")
some accounts get server creation refused at random, so only an actual
`hcloud server create` proves it.
