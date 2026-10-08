#!/usr/bin/env bash
# Fastfetch redrawn slowly in a loop: logo gradient drifts and stats (RAM, uptime...) stay live.
# Any key stops it.
D=~/.config/fastfetch
F="--logo-type kitty-direct --logo"
DELAY=1.5   # seconds between redraws
[ -t 1 ] || { fastfetch; exit; }
[ "$TERM" = xterm-kitty ] || { fastfetch; exit; }
out=$(fastfetch $F $D/frames/f0.png); n=$(printf '%s\n' "$out" | wc -l)
printf '\e[?25l'; printf '%s\n' "$out"
trap 'printf "\e[?25h"' EXIT
while :; do
  for i in $(seq 1 11) 0; do
    read -rsn1 -t $DELAY && break 2
    printf '\e[%dA' "$n"; fastfetch $F $D/frames/f$i.png
  done
done
