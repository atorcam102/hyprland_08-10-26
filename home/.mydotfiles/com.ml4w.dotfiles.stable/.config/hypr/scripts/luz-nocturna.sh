#!/usr/bin/env bash
# Alterna la luz nocturna (hyprsunset).
if pgrep -x hyprsunset >/dev/null; then
    pkill -x hyprsunset; notify-send -t 1500 "Luz nocturna" "desactivada"
else
    nohup hyprsunset -t 3800 >/dev/null 2>&1 & notify-send -t 1500 "Luz nocturna" "activada (3800K)"
fi
