# spotify — feature notes

2026-06-26: Added featureMeta + a feature test.

The feature uses only `homeManager.spotify` (no nixos module) — it requires `["wiktor"]`.
Spicetify-nix wraps the Spotify binary and exposes it as `spotify` in the user's HM profile.
The feature test requires `nixpkgs.config.allowUnfree = true` in the VM's extra modules — spotify is unfree.

Symptom: The VM eval may hang if spicetify tries to fetch resources from the internet during HM activation.
Cause: During `home-manager-wiktor.service`, spicetify may try to reach the Spotify CDN.
Fix: Not observed in headless tests so far; if it happens, add `networking.firewall.allowedTCPPorts` or stub an HTTP server.
