# fish_command_not_found handler: says what to run instead of just failing.
#   1. a package ships exactly this binary (nix-index)  -> `nix shell` commands
#   2. otherwise, name/description search (`nix search`) -> installed commands
#      first, then nixpkgs packages. `hetzner` finds `hcloud` this way.
cmd=$1
limit=5
wait_ticks=30 # tenths of a second to wait for `nix search` before giving up
min_warm_kb=$((6 * 1024 * 1024)) # an uncached nixpkgs eval peaks around 4.5 GiB

not_found() {
  echo "$cmd: command not found" >&2
}

# Same guard as nix-index's own handler: pipes and Midnight Commander get the
# plain message. So does a path, which no package could provide.
if [ -n "${MC_SID-}" ] || ! [ -t 1 ] || [[ $cmd == */* ]]; then
  not_found
  exit 127
fi

not_found

# Attribute names, shortest (usually the canonical package) first. Sub-attrs
# like tests.* or haskellPackages.* only count when nothing top-level has it.
attrs=$(nix-locate --minimal --no-group --type x --type s --whole-name --at-root "/bin/$cmd" 2>/dev/null | sed 's/\.out$//' || true)
top_level=$(grep -v '\.' <<<"$attrs" || true)
[ -n "$top_level" ] && attrs=$top_level
if [ -n "$attrs" ]; then
  echo "Provided by:" >&2
  awk '{ print length, $0 }' <<<"$attrs" | sort -n | cut -d' ' -f2- | head -n "$limit" |
    while read -r attr; do
      echo "  nix shell nixpkgs#$attr -c $cmd" >&2
    done
  exit 127
fi

# Two letters match half of nixpkgs.
[ "${#cmd}" -ge 3 ] || exit 127

# shellcheck disable=SC2001,SC2016 # a literal character class, not an expansion
regex=$(sed 's/[][\.*^$()+?{}|]/\\&/g' <<<"$cmd")
results=$(mktemp)
trap 'rm -f "$results"' EXIT

# The search outlives this script on a cold cache: its result is what warms the
# eval cache. setsid detaches it from the terminal; the lock keeps a second typo
# from starting a second 4.5 GiB eval.
setsid flock -n -F -E 75 "${XDG_RUNTIME_DIR:-/tmp}/command-not-found-$UID.lock" \
  nix --extra-experimental-features "nix-command flakes" search --offline --json nixpkgs -- "$regex" \
  >"$results" 2>/dev/null </dev/null &
search=$!

ticks=0
while kill -0 "$search" 2>/dev/null && [ "$ticks" -lt "$wait_ticks" ]; do
  sleep 0.1
  ticks=$((ticks + 1))
done

if kill -0 "$search" 2>/dev/null; then
  available_kb=$(awk '/^MemAvailable:/ { print $2 }' /proc/meminfo)
  if [ "$available_kb" -ge "$min_warm_kb" ]; then
    echo "Package search is building its cache in the background; try again in a minute." >&2
  else
    kill "$search" 2>/dev/null || true
    echo "Package search has no cache yet. Build it with: nix search nixpkgs $cmd" >&2
  fi
  exit 127
fi

status=0
wait "$search" || status=$?
if [ "$status" -eq 75 ]; then
  echo "Package search is building its cache in the background; try again in a minute." >&2
  exit 127
fi
[ "$status" -eq 0 ] || exit 127

# rank <TAB> attr <TAB> description: installed, then name match, then description
# match. Top-level attributes only, the rest are language-set duplicates.
ranked=$(
  jq -r '
    to_entries[]
    | (.key | sub("^legacyPackages\\.[^.]+\\."; "")) as $attr
    | select($attr | contains(".") | not)
    | [$attr, (.value.description | gsub("\\s+"; " "))]
    | @tsv
  ' "$results" |
    while IFS=$'\t' read -r attr description; do
      if command -v "$attr" >/dev/null; then
        rank=0
      elif [[ ${attr,,} == *"${cmd,,}"* ]]; then
        rank=1
      else
        rank=2
      fi
      printf '%s\t%s\t%s\n' "$rank" "$attr" "$description"
    done | sort -t$'\t' -k1,1n -k2,2
)
[ -n "$ranked" ] || exit 127

total=$(wc -l <<<"$ranked")
heading=
while IFS=$'\t' read -r rank attr description; do
  if [ "$rank" -eq 0 ]; then
    wanted="Installed, did you mean:"
    suggestion=$attr
  else
    wanted="In nixpkgs:"
    suggestion="nix shell nixpkgs#$attr"
  fi
  if [ "$wanted" != "$heading" ]; then
    heading=$wanted
    echo "$heading" >&2
  fi
  printf '  %-32s %s\n' "$suggestion" "${description:0:70}" >&2
done < <(head -n "$limit" <<<"$ranked")
if [ "$total" -gt "$limit" ]; then
  echo "...and $((total - limit)) more: nix search nixpkgs $cmd" >&2
fi
exit 127
