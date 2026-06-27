# Toggle a quake-style scratchpad terminal on niri.
#
# The scratchpad is a standalone ghostty instance tagged app-id=quickterm, which
# a niri window-rule floats on top of the current workspace. Instead of killing
# the window when dismissed, we stash it (shell and any running command intact)
# on the named "scratch" workspace, then pull it back to whatever workspace is
# focused when summoned again. First invocation spawns it.
# Must be a valid GTK application ID (reverse-DNS, >=2 dot-separated segments),
# otherwise ghostty rejects --class and falls back to its default app-id.
app_id="com.quickterm.Scratchpad"
scratch="scratch"

win=$(niri msg -j windows | jq -c --arg a "$app_id" 'map(select(.app_id == $a)) | first // empty')

if [ -z "$win" ]; then
  # Not running yet: launch a dedicated instance. It must NOT join the shared
  # gtk-single-instance ghostty server, or it would inherit that server's
  # app-id and never match the window-rule. Its own instance honours --class.
  exec ghostty --class="$app_id" --gtk-single-instance=false \
    --window-width=110 --window-height=32
fi

id=$(printf '%s' "$win" | jq -r '.id')
win_ws=$(printf '%s' "$win" | jq -r '.workspace_id')
focused_ws=$(niri msg -j workspaces | jq -r 'map(select(.is_focused)) | first | .id')

if [ "$win_ws" = "$focused_ws" ]; then
  # Visible on the active workspace -> stash it, keep focus where it is.
  niri msg action move-window-to-workspace --window-id "$id" --focus false "$scratch"
else
  # Stashed (or on another workspace) -> pull onto the focused workspace.
  # move's --focus only follows an already-focused window, so focus explicitly.
  focused_idx=$(niri msg -j workspaces | jq -r 'map(select(.is_focused)) | first | .idx')
  niri msg action move-window-to-workspace --window-id "$id" --focus true "$focused_idx"
  niri msg action focus-window --id "$id"
fi
