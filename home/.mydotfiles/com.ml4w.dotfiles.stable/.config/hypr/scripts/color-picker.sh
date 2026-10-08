#!/usr/bin/env bash
# Selector de color: copia el hex al portapapeles.
c=$(hyprpicker -a -n) && notify-send -t 2500 "Color copiado" "$c"
