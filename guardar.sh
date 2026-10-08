#!/usr/bin/env bash
#       _ _                 _   _   _   _
#  __ _| | |__  ___ _ _ _ _| |_| |_| |_| |_
# / _` | | '_ \/ -_) '_| '_|  _|  _|  _|  _|
# \__,_|_|_.__/\___|_| |_|  \__|\__|\__|\__|
#
# guardar.sh — copia el escritorio actual de esta máquina dentro del repo.
# Ejecútalo cuando cambies algo y luego: git add -A && git commit && git push
set -euo pipefail

REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
H="$HOME/"
DST="$REPO/home"
RS=(rsync -a --mkpath --delete --exclude=.git --exclude='*.antes-*' --exclude='*.backup-*' --exclude='*.bak')

echo ":: Guardando dotfiles en $REPO"
mkdir -p "$DST/.config" "$DST/.local/share" "$DST/.local/bin" "$REPO/packages" "$REPO/assets" "$REPO/system" "$REPO/proyectos"

# 1. Dotfiles ML4W (la fuente real de los symlinks de ~/.config)
"${RS[@]}" "${H}.mydotfiles/com.ml4w.dotfiles.stable/" "$DST/.mydotfiles/com.ml4w.dotfiles.stable/"

# 2. Configs que no son symlink
for d in ml4w-dock ml4w-statusbar estilos ml4w-dotfiles-installer; do
    [ -e "${H}.config/$d" ] && "${RS[@]}" "${H}.config/$d/" "$DST/.config/$d/"
done
for f in mimeapps.list pavucontrol.ini user-dirs.dirs user-dirs.locale; do
    [ -e "${H}.config/$f" ] && cp -a "${H}.config/$f" "$DST/.config/$f"
done

# 3. Apps en ~/.local/share (dock, overview, el pingüino, ml4w)
for d in window-pet ml4w-dock quickshell-overview ml4w-dotfiles-installer ml4w-dotfiles-settings; do
    [ -e "${H}.local/share/$d" ] && "${RS[@]}" "${H}.local/share/$d/" "$DST/.local/share/$d/"
done

# 4. Scripts de ~/.local/bin (los binarios se reinstalan/compilan)
for f in matugen ml4w-dotfiles-installer ml4w-dotfiles-settings; do
    cp -a "${H}.local/bin/$f" "$DST/.local/bin/$f"
done

# 5. Shell
cp -a "${H}.bash_profile" "${H}.bashrc_custom" "$DST/"

# 6. Iconos y cursores (kora + Bibata)
tar -C "${H}.local/share/icons" -czf "$REPO/assets/icons.tar.gz" .

# 7. shotbar (solo código; se compila al instalar)
rsync -a --mkpath --delete --exclude=target --exclude=.git "${H}Proyectos/shotbar/" "$REPO/proyectos/shotbar/"

# 8. Ajustes GTK/GNOME (tema oscuro, cursor, fuente, iconos)
dconf dump / > "$REPO/system/dconf.ini"

# 9. Listas de paquetes (sin kernel/arranque/drivers propios de esta máquina)
SKIP='^(base|linux|linux-aarch64|linux-firmware|grub|efibootmgr|efivar|btrfs-progs|dosfstools|e2fsprogs|systemd-ukify|spice-vdagent|kmscon|yay|sudo)$'
pacman -Qqen | /usr/bin/grep -Ev "$SKIP" > "$REPO/packages/pacman.txt"
pacman -Qqem | /usr/bin/grep -Ev "$SKIP" > "$REPO/packages/aur.txt"
flatpak list --app --columns=application 2>/dev/null > "$REPO/packages/flatpak.txt" || true
pipx list --short 2>/dev/null | awk '{print $1}' > "$REPO/packages/pipx.txt" || true

echo ":: Listo. Revisa con: git -C $REPO status"
