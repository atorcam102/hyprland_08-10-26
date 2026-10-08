#!/usr/bin/env bash
# Instala shotbar e integra el módulo en la statusbar Quickshell de ML4W.
# Idempotente: se puede ejecutar varias veces. Hace backup antes de tocar nada.
set -euo pipefail
cd "$(dirname "$0")/.."
B=backup-shotbar

echo ":: Dependencias"
need=()
for p in grim slurp wl-clipboard gtk4 gtk4-layer-shell rust libnotify jq; do
    pacman -Q "$p" &>/dev/null || need+=("$p")
done
((${#need[@]})) && sudo pacman -S --needed "${need[@]}" || echo "   todo instalado"

echo ":: Compilando ($(uname -m))"
cargo build --release
install -Dm755 target/release/shotbar "$HOME/.local/bin/shotbar"

echo ":: Módulo de la barra"
Q="$HOME/.config/quickshell/StatusbarApp"
W="$Q/StatusbarWindow.qml"
install -m644 assets/ScreenshotsModule.qml "$Q/ScreenshotsModule.qml"
if ! grep -q cScreenshots "$W"; then
    cp -n "$W" "$W.$B"
    sed -i 's|^\(    Component { id: cPowerProfile; PowerProfileModule {} }\)$|\1\n    Component { id: cScreenshots;  ScreenshotsModule {} }|' "$W"
    sed -i 's|^\(        "powerprofile": cPowerProfile\)$|\1,\n        "screenshots":  cScreenshots|' "$W"
fi
C="$HOME/.config/ml4w-statusbar/config.json"
if [ -f "$C" ] && ! grep -q '"screenshots"' "$C"; then
    cp -n "$C" "$C.$B"
    tmp=$(mktemp)
    jq '.modules.right |= (if index("screenshots") then . else ((index("systemtray") // -1) as $i | .[:$i+1] + ["screenshots"] + .[$i+1:]) end)' "$C" > "$tmp" && mv "$tmp" "$C"
fi

echo ":: Atajos de Hyprland"
K="$HOME/.config/hypr/conf/keybindings/custom.lua"
if ! grep -q 'shotbar region' "$K"; then
    cp -n "$K" "$K.$B"
    cat >> "$K" <<'LUA'

-- Capturas con historial temporal (shotbar): clipboard + panel en la barra
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("shotbar region"), { description = "Captura de una zona (copiada + historial)" })
hl.bind("PRINT",                   hl.dsp.exec_cmd("shotbar region"), { description = "Captura de una zona (copiada + historial)" })
hl.bind("SHIFT + PRINT",           hl.dsp.exec_cmd("shotbar screen"), { description = "Captura de la pantalla completa" })
hl.bind("CTRL + PRINT",            hl.dsp.exec_cmd("shotbar window"), { description = "Captura de una ventana" })
hl.bind(mainMod .. " + ALT + P",   hl.dsp.exec_cmd("shotbar panel"),  { description = "Panel de capturas" })
hl.layer_rule({ match = { namespace = "selection" }, no_anim = true })
hl.layer_rule({ match = { namespace = "shotbar" }, blur = true, ignore_alpha = 0.5, no_anim = true })
hl.layer_rule({ match = { namespace = "shotbar-preview" }, no_anim = true })
LUA
fi
echo "   ojo: SUPER+SHIFT+S no debe estar usado en default.lua (aquí se movió el scratchpad a SUPER+ALT+S)"

hyprctl reload >/dev/null || true
qs ipc call statusbar reload >/dev/null 2>&1 || true
qs ipc call theme-manager reload >/dev/null 2>&1 || true
echo ":: Listo. Prueba: SUPER+SHIFT+S"
