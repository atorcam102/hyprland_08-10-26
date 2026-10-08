#!/usr/bin/env bash
# Terminal desplegable en un workspace especial.
if ! hyprctl clients -j | grep -q '"class": "scratchpad"'; then
    kitty --class scratchpad >/dev/null 2>&1 &
    sleep 0.7
else
    hyprctl dispatch 'hl.dsp.workspace.toggle_special("scratch")' >/dev/null
fi
