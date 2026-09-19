#!/bin/sh
# Live-runtime check for the `firefox` feature (Tier-1-live, /nix-sandbox).
#
# The feature test asserts the binary is on PATH. That is true of a browser that
# crashes on startup, renders a blank surface, or never maps a window at all —
# which is exactly the class of breakage a VM's software GL likes to produce.
# So this one launches it and waits for a real window in niri's window tree.
fail=0
ok() { echo "ok: $1"; }
bad() {
  echo "fail: $1" >&2
  fail=1
}

# Wait for a predicate instead of sleeping: llvmpipe makes startup times
# unpredictable, and a fixed sleep buys a flaky check.
wait_for() { # wait_for <seconds> <shell-condition>
  _left="$1"
  shift
  while [ "$_left" -gt 0 ]; do
    if eval "$@" >/dev/null 2>&1; then return 0; fi
    _left=$((_left - 1))
    sleep 1
  done
  return 1
}

has_firefox_window="niri msg -j windows | jq -e 'any(.[]; (.app_id // \"\") | test(\"firefox\"; \"i\"))'"

if command -v firefox >/dev/null; then
  ok "firefox is on the tester's PATH"
else
  bad "firefox is not on PATH"
  exit 1
fi

# home-manager's programs.firefox owns the profile; without it the browser still
# starts, but none of the feature's configuration is in effect.
if [ -d "$HOME/.mozilla/firefox" ]; then
  ok "home-manager profile directory exists"
else
  bad "no ~/.mozilla/firefox — the home-manager half did not activate"
fi

setsid firefox >/tmp/firefox-launch.log 2>&1 &

if wait_for 90 "$has_firefox_window"; then
  ok "a firefox window is mapped in the niri session"
else
  bad "no firefox window appeared within 90s — see /tmp/firefox-launch.log"
fi

# A mapped window with an empty title is usually a surface that never finished
# loading; the title is the cheapest evidence the browser actually ran.
title="$(niri msg -j windows |
  jq -r 'map(select((.app_id // "") | test("firefox"; "i"))) | .[0].title // ""')"
if [ -n "$title" ]; then
  ok "window has a title: $title"
else
  bad "the firefox window has no title — it probably never finished starting"
fi

exit $fail
