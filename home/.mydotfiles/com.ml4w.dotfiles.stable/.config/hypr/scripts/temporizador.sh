#!/usr/bin/env bash
# Temporizador rápido: pide minutos en rofi y avisa al terminar.
m=$(printf '5\n10\n15\n25\n45\n60\n' | rofi -dmenu -p "Temporizador (min)") || exit 0
[[ "$m" =~ ^[0-9]+$ ]] || exit 1
notify-send -t 2000 "Temporizador" "$m min en marcha"
( sleep $((m*60)); notify-send -u critical "Temporizador" "Han pasado $m min" ) >/dev/null 2>&1 &
disown
