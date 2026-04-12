#!/usr/bin/env bash

PROJ_DIR="$HOME/Projects/modern-cv"

# 1. Spawning apps
niri msg action spawn -- "code" "$PROJ_DIR" &
niri msg action spawn -- "alacritty" "--working-directory" "$PROJ_DIR" &
niri msg action spawn -- "alacritty" "--working-directory" "$PROJ_DIR" "-e" "sh" "-c" "opencode ." &
niri msg action spawn -- "brave" &

