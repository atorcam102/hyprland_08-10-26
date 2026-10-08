#!/usr/bin/env bash
# Modo foco: sin gaps, sin bordes ni esquinas. Segunda pulsación = restaurar.
F="$HOME/.cache/modo-foco"
if [ -f "$F" ]; then
    rm "$F"; hyprctl reload >/dev/null; notify-send -t 1500 "Modo foco" "desactivado"
else
    touch "$F"
    hyprctl dispatch 'hl.config({general={gaps_in=0,gaps_out=0,border_size=0},decoration={rounding=0,inactive_opacity=1.0}})' >/dev/null 2>&1
    notify-send -t 1500 "Modo foco" "activado"
fi
