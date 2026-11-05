# file-search notes

## Hidden directories are skipped by default (2026-11-05)

`>file features.json` finds nothing, because the plugin runs plain `fd`, which
skips hidden paths (`~/.config/...`) and anything matched by `.gitignore`. Turn
on `showHidden` in Noctalia Settings → Plugins → File Search to include dotdirs
(at the cost of `~/.cache` noise). The query is an fd regex, not a glob.

## Noctalia v5 (2026-11-05)

The plugin comes from the *legacy v4* registry (`noctalia-dev/noctalia-plugins`),
which matches the noctalia-shell 4.7.x from nixpkgs. Noctalia v5 is a rewrite
with its own plugin system (`/fs` prefix there), and a Reddit port of the v4
plugins to v5 reported file-search as not working. Revisit when moving to v5.
