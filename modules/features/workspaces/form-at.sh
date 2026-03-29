#!/usr/bin/env bash

PROJ_DIR="$HOME/Projects/form-at"
LEFT_MONITOR="HP Inc. HP E243 CNC0171FR8"
RIGHT_MONITOR="Ancor Communications Inc ASUS VX239 G6LMTJ040329"

# 1. Spawning apps
niri msg action spawn -- "code" "$PROJ_DIR/frontend" &
niri msg action spawn -- "firefox" "--new-window" "http://localhost:3000" &
niri msg action spawn -- "discord" &
niri msg action spawn -- "alacritty" "--working-directory" "$PROJ_DIR" "-e" "sh" "-c" "docker compose -f docker-compose.dev.yaml up --build --watch; exec bash" &

