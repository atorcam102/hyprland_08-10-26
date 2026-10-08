#!/usr/bin/env bash
# Launches the window pet once the compositor is ready; safe to run repeatedly.
DIR="$HOME/.local/share/window-pet"
for _ in $(seq 1 30); do hyprctl monitors >/dev/null 2>&1 && break; sleep 1; done
sleep 2
pgrep -f "^qs -n -p $DIR\$" >/dev/null && exit 0
exec qs -n -p "$DIR"
