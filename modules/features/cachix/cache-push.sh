# Push locally-built store paths of a closure to the personal Cachix cache.
# Usage: cache-push [store-path]   (default: /run/current-system)
#
# Only paths WITHOUT a binary-cache signature are pushed: anything signed was
# substituted from cache.nixos.org / an upstream cache and can always be
# re-downloaded from there, so re-uploading it would only burn the 5 GB free
# Cachix quota. Unsigned paths are exactly the ones this machine had to build
# itself (unfree repackages like vscode/cursor, overridden drvs, ...).

CACHE_NAME=wiktor-nixos
TOKEN_FILE=/run/secrets/cachixAuthToken

target="${1:-/run/current-system}"

if [[ ! -r "$TOKEN_FILE" ]]; then
  echo "cache-push: cannot read $TOKEN_FILE — add cachixAuthToken to secrets.yaml (sops secrets.yaml), then re-activate (nh os test)" >&2
  exit 1
fi

CACHIX_AUTH_TOKEN="$(<"$TOKEN_FILE")"
if [[ "$CACHIX_AUTH_TOKEN" == "CHANGE_ME" ]]; then
  echo "cache-push: cachixAuthToken is still the CHANGE_ME placeholder — put your real token in secrets.yaml and re-activate" >&2
  exit 1
fi
export CACHIX_AUTH_TOKEN

paths="$(
  nix path-info -r "$target" --json |
    jq -r 'to_entries[] | select((.value.signatures // []) | length == 0) | .key'
)"

if [[ -z "$paths" ]]; then
  echo "cache-push: nothing to push — every path in the closure is already signed by a binary cache"
  exit 0
fi

echo "cache-push: pushing $(wc -l <<<"$paths") locally-built path(s) to $CACHE_NAME"
cachix push "$CACHE_NAME" <<<"$paths"
