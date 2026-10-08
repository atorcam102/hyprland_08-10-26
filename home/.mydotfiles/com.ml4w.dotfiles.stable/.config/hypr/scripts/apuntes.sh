#!/usr/bin/env bash
# Apunte rápido: escribe una línea en rofi y se guarda con fecha en ~/Documentos/apuntes.md
# (Con Escape no guarda nada; si escribes "ver" abre el archivo.)
A="$HOME/Documentos/apuntes.md"
t=$(rofi -dmenu -p "Apunte" -l 0) || exit 0
[ -z "$t" ] && exit 0
if [ "$t" = "ver" ]; then
    kitty --class flotante -e "${EDITOR:-nano}" "$A" & exit 0
fi
[ -f "$A" ] || printf '# Apuntes de Albert\n\n' > "$A"
printf -- '- **%s** %s\n' "$(date '+%d/%m %H:%M')" "$t" >> "$A"
notify-send -a alberrtttt -t 2000 "Apuntado" "$t"
