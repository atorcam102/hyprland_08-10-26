#!/usr/bin/env bash
# Buscador rápido. Prefijos: "yt algo" → YouTube, "w algo" → Wikipedia (es),
# "aur algo" → AUR, "gh algo" → GitHub. Sin prefijo → Google.
q=$(rofi -dmenu -p "Buscar" -l 0) || exit 0
[ -z "$q" ] && exit 0
enc() { jq -rn --arg s "$1" '$s|@uri'; }
case "$q" in
  "yt "*)  u="https://www.youtube.com/results?search_query=$(enc "${q#yt }")" ;;
  "w "*)   u="https://es.wikipedia.org/w/index.php?search=$(enc "${q#w }")" ;;
  "aur "*) u="https://aur.archlinux.org/packages?K=$(enc "${q#aur }")" ;;
  "gh "*)  u="https://github.com/search?q=$(enc "${q#gh }")" ;;
  *)       u="https://www.google.com/search?q=$(enc "$q")" ;;
esac
xdg-open "$u" >/dev/null 2>&1 &
