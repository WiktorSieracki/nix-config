#!/usr/bin/env bash
# Prints the root flake inputs worth bumping, space-separated: every input
# except those referenced only by features that no host enables.
#
# An input is "used" when any file mentioning `inputs.<name>` either
#   - lies outside modules/features/ (scaffolding, hosts, the test harness), or
#   - declares no `flake.featureMeta.<x>` (a helper module: assume used), or
#   - declares a feature that some host's features.json enables.
# Inputs never mentioned in modules/ (nixpkgs, import-tree, ...) are wired in
# flake.nix itself and always count as used.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

enabled=$(nix eval --json .#hostSpecs --apply '
  specs: builtins.concatLists (map (s: s.features) (builtins.attrValues specs))
' | jq -r '.[]' | sort -u)

used=()
for input in $(jq -r '.nodes.root.inputs | keys[]' flake.lock); do
  files=$(grep -rlE "inputs\.\"?${input}\"?([^a-zA-Z0-9_-]|$)" modules --include='*.nix' || true)
  keep=0
  if [ -z "$files" ]; then
    keep=1
  fi
  for f in $files; do
    case "$f" in
      modules/features/*) ;;
      *) keep=1; break ;;
    esac
    features=$(grep -oE 'flake\.featureMeta\.[a-zA-Z0-9_-]+' "$f" | sed 's/^flake\.featureMeta\.//' || true)
    if [ -z "$features" ]; then
      keep=1; break
    fi
    for feat in $features; do
      if grep -qxF "$feat" <<<"$enabled"; then keep=1; break 2; fi
    done
  done
  if [ "$keep" = 1 ]; then
    used+=("$input")
  else
    echo "skipping '$input': only used by features no host enables" >&2
  fi
done

echo "${used[*]}"
