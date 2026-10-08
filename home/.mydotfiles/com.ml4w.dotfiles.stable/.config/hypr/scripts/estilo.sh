#!/usr/bin/env bash
# Cambia de estilo: estilo.sh horizonte | alberrtttt | radical | suave | clasico   (sin argumento: menú rofi)
D="$HOME/.config/hypr/conf"
S="${1:-$(printf 'horizonte\nalberrtttt\nradical\nsuave\nclasico\n' | rofi -dmenu -p Estilo)}"
case "$S" in
  horizonte) V=horizonte ;;
  alberrtttt) V=alberrtttt ;;
  radical) V=radical ;;
  suave)   V=minimal-dark ;;
  clasico) V=default ;;
  *) exit 1 ;;
esac
for f in decoration window animation; do
    sed -i "s/^local name = \".*\"/local name = \"$V.lua\"/" "$D/$f.lua"
done
mkdir -p "$HOME/.config/ml4w-statusbar" "$HOME/.config/ml4w-dock"
P="$HOME/.config/estilos/$S"
[ -f "$P/statusbar.json" ] && cp "$P/statusbar.json" "$HOME/.config/ml4w-statusbar/config.json"
[ -f "$P/dock.json" ] && cp "$P/dock.json" "$HOME/.config/ml4w-dock/config.json"
[ -f "$P/rofi-border.rasi" ] && cp "$P/rofi-border.rasi" "$HOME/.config/ml4w/settings/rofi-border.rasi"
[ -f "$P/rofi-border-radius.rasi" ] && cp "$P/rofi-border-radius.rasi" "$HOME/.config/ml4w/settings/rofi-border-radius.rasi"
hyprctl reload >/dev/null; qs ipc call statusbar reload; sleep 0.5; qs ipc call theme-manager reload; ml4w-dock reload
notify-send -t 1500 "Estilo" "$S"
