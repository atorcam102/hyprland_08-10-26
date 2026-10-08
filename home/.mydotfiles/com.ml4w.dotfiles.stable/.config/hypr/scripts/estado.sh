#!/usr/bin/env bash
# Parte del sistema en una notificación: CPU, RAM, disco, temperatura, tiempo encendido.
read -r _ a1 b1 c1 d1 e1 f1 g1 _ < /proc/stat; sleep 0.4
read -r _ a2 b2 c2 d2 e2 f2 g2 _ < /proc/stat
t=$(( (a2+b2+c2+d2+e2+f2+g2) - (a1+b1+c1+d1+e1+f1+g1) ))
cpu=$(( t > 0 ? 100 * (t - (d2-d1) - (e2-e1)) / t : 0 ))
ram=$(free -h --si | awk '/^Mem/ {print $3 " de " $2}')
disco=$(df -h / | awk 'NR==2 {print $3 " de " $2 " (" $5 ")"}')
temp=$(sensors 2>/dev/null | grep -m1 -oE '\+[0-9]+\.[0-9]°C' | tr -d +)
up=$(uptime -p | sed 's/up /encendido /;s/hours\?/h/;s/minutes\?/min/;s/days\?/días/')
msg="CPU  ${cpu}%\nRAM  ${ram}\nDisco  ${disco}"
[ -n "$temp" ] && msg="$msg\nTemp  $temp"
notify-send -a alberrtttt -t 6000 "Así va la máquina, Albert" "$msg\n$up"
