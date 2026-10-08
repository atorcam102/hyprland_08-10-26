#!/usr/bin/env bash
# Saludo de Albert al arrancar Hyprland (o con SUPER + F12).
h=$(date +%H)
if   [ "$h" -lt 6 ];  then s="Buenas noches, trasnochador"
elif [ "$h" -lt 14 ]; then s="Buenos días, Albert"
elif [ "$h" -lt 21 ]; then s="Buenas tardes, Albert"
else                       s="Buenas noches, Albert"
fi
d=$(LC_TIME=es_ES.UTF-8 date +"%A %-d de %B · %H:%M")
notify-send -a "alberrtttt" -t 5000 "$s" "$d\nEste es tu Hyprland. SUPER + CTRL + K para ver los atajos."
