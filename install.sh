#!/usr/bin/env bash
#       _ _                 _   _   _   _
#  __ _| | |__  ___ _ _ _ _| |_| |_| |_| |_
# / _` | | '_ \/ -_) '_| '_|  _|  _|  _|  _|
# \__,_|_|_.__/\___|_| |_|  \__|\__|\__|\__|
#
# install.sh — deja un Arch Linux recién instalado igual que el de Albert:
# Hyprland + ML4W "Horizonte", colores matugen, dock, barra, el pingüino,
# estilos, iconos/cursor, shotbar, fuentes y atajos.
#
# Uso:   git clone https://github.com/atorcam102/hyprland_08-10-26 && cd hyprland_08-10-26 && ./install.sh
# Flags: --sin-paquetes   (solo copia configuración)
#        --sin-sistema    (no toca locale/teclado/autologin)
#        --si             (responde "sí" a todo)
set -euo pipefail

REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOT="$HOME/.mydotfiles/com.ml4w.dotfiles.stable"
FECHA="$(date +%Y%m%d-%H%M%S)"
BACKUP="$HOME/.backup-antes-de-hyprland-$FECHA"

PAQUETES=1; SISTEMA=1; SI=0
for a in "$@"; do
    case "$a" in
        --sin-paquetes) PAQUETES=0 ;;
        --sin-sistema)  SISTEMA=0 ;;
        --si|-y)        SI=1 ;;
        -h|--help) sed -n '2,16p' "$0"; exit 0 ;;
        *) echo "Opción desconocida: $a"; exit 1 ;;
    esac
done

azul()  { printf '\e[1;34m:: %s\e[0m\n' "$*"; }
ok()    { printf '\e[1;32m   ✔ %s\e[0m\n' "$*"; }
aviso() { printf '\e[1;33m   ! %s\e[0m\n' "$*"; }
pregunta() {
    [ "$SI" = 1 ] && return 0
    read -r -p "   ? $1 [S/n] " r
    [[ -z "$r" || "$r" =~ ^[SsYy] ]]
}

# ---------------------------------------------------------------- comprobaciones
[ "$EUID" -eq 0 ] && { echo "No lo ejecutes como root; usa tu usuario normal (con sudo)."; exit 1; }
command -v pacman >/dev/null || { echo "Esto es para Arch Linux (pacman)."; exit 1; }

echo
echo "  Instalador del escritorio Hyprland de Albert  ($(uname -m))"
echo "  Repo: $REPO"
echo
pregunta "¿Continuar?" || exit 0
{ [ "$PAQUETES" = 1 ] || [ "$SISTEMA" = 1 ]; } && sudo -v

# ---------------------------------------------------------------- paquetes
if [ "$PAQUETES" = 1 ]; then
    azul "Actualizando el sistema e instalando lo básico"
    sudo pacman -Syu --needed --noconfirm base-devel git rsync curl

    if ! command -v yay >/dev/null; then
        azul "Instalando yay (AUR)"
        T="$(mktemp -d)"
        git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$T/yay-bin"
        (cd "$T/yay-bin" && makepkg -si --noconfirm)
        rm -rf "$T"
    fi
    ok "yay listo"

    azul "Instalando paquetes"
    mapfile -t TODOS < <(cat "$REPO/packages/pacman.txt" "$REPO/packages/aur.txt" | sed '/^\s*$/d' | sort -u)
    TODOS+=(gtk4 gtk4-layer-shell xdg-user-dirs pipewire pipewire-pulse wireplumber)
    REPO_PKGS=(); AUR_PKGS=()
    for p in "${TODOS[@]}"; do
        if pacman -Si "$p" >/dev/null 2>&1; then REPO_PKGS+=("$p"); else AUR_PKGS+=("$p"); fi
    done
    sudo pacman -S --needed --noconfirm "${REPO_PKGS[@]}"
    if [ "${#AUR_PKGS[@]}" -gt 0 ]; then
        echo "   Desde AUR: ${AUR_PKGS[*]}"
        for p in "${AUR_PKGS[@]}"; do
            yay -S --needed --noconfirm "$p" || aviso "No se pudo instalar $p (sigue igualmente)"
        done
    fi
    ok "Paquetes instalados"

    if [ -s "$REPO/packages/flatpak.txt" ]; then
        azul "Flatpaks"
        flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
        xargs -a "$REPO/packages/flatpak.txt" -r flatpak install --user -y --noninteractive flathub || aviso "Algún flatpak falló"
    fi

    if [ -s "$REPO/packages/pipx.txt" ]; then
        azul "pipx (pywalfox)"
        while read -r p; do [ -n "$p" ] && { pipx install "$p" || aviso "pipx $p falló"; }; done < "$REPO/packages/pipx.txt"
        command -v pywalfox >/dev/null && pywalfox install >/dev/null 2>&1 || true
    fi

    if ! command -v oh-my-posh >/dev/null; then
        azul "oh-my-posh"
        mkdir -p "$HOME/.local/bin"
        curl -s https://ohmyposh.dev/install.sh | bash -s -- -d "$HOME/.local/bin" || aviso "oh-my-posh falló"
    fi
fi

# ---------------------------------------------------------------- copia de seguridad
azul "Copia de seguridad de lo que vaya a sobrescribirse → $BACKUP"
mkdir -p "$BACKUP/.config"
respaldar() {  # $1 = ruta relativa a $HOME
    local src="$HOME/$1"
    if [ -e "$src" ] || [ -L "$src" ]; then
        mkdir -p "$BACKUP/$(dirname "$1")"
        mv "$src" "$BACKUP/$1"
    fi
}
for d in "$REPO"/home/.mydotfiles/com.ml4w.dotfiles.stable/.config/*; do
    respaldar ".config/$(basename "$d")"
done
for sub in .config .local/share .local/bin; do
    for d in "$REPO/home/$sub"/*; do respaldar "$sub/$(basename "$d")"; done
done
for f in .bashrc .zshrc .Xresources .gtkrc-2.0 .bash_profile .bashrc_custom; do respaldar "$f"; done
[ -d "$HOME/.mydotfiles/com.ml4w.dotfiles.stable" ] && respaldar ".mydotfiles/com.ml4w.dotfiles.stable"
ok "Hecho"

# ---------------------------------------------------------------- dotfiles
azul "Copiando configuración"
rsync -a "$REPO/home/" "$HOME/"

# symlinks de ML4W: ~/.config/X -> ../.mydotfiles/com.ml4w.dotfiles.stable/.config/X
for d in "$DOT"/.config/*; do
    n="$(basename "$d")"
    ln -sfn "../.mydotfiles/com.ml4w.dotfiles.stable/.config/$n" "$HOME/.config/$n"
done
for f in .bashrc .zshrc .Xresources .gtkrc-2.0; do
    [ -e "$DOT/$f" ] && ln -sfn ".mydotfiles/com.ml4w.dotfiles.stable/$f" "$HOME/$f"
done
mkdir -p "$HOME/.local/bin"
ln -sfn "$HOME/.local/share/ml4w-dock/bin/ml4w-dock" "$HOME/.local/bin/ml4w-dock"
chmod +x "$HOME"/.local/bin/* "$HOME/.local/share/window-pet/start.sh" 2>/dev/null || true
find "$DOT/.config/hypr/scripts" "$DOT/.config/ml4w/scripts" "$DOT/.config/ml4w/bin" -type f -exec chmod +x {} + 2>/dev/null || true
ok "Dotfiles, dock, barra, estilos y pingüino en su sitio"

azul "Iconos y cursores (kora, Bibata)"
mkdir -p "$HOME/.local/share/icons"
tar -xzf "$REPO/assets/icons.tar.gz" -C "$HOME/.local/share/icons"
ok "Hecho"

azul "Carpetas de usuario en español"
LC_ALL=es_ES.UTF-8 xdg-user-dirs-update 2>/dev/null || true
for d in Escritorio Descargas Plantillas Público Documentos Música Imágenes Vídeos Proyectos; do mkdir -p "$HOME/$d"; done
ok "Hecho"

azul "Ajustes GTK (tema oscuro, cursor, fuente JetBrainsMono, iconos kora)"
if command -v dconf >/dev/null; then
    dbus-run-session -- dconf load / < "$REPO/system/dconf.ini" 2>/dev/null || dconf load / < "$REPO/system/dconf.ini" || aviso "dconf no cargó (se aplica al iniciar Hyprland)"
fi
ok "Hecho"

# ---------------------------------------------------------------- shotbar
if command -v cargo >/dev/null; then
    azul "Compilando shotbar (capturas de pantalla)"
    mkdir -p "$HOME/Proyectos"
    rsync -a "$REPO/proyectos/shotbar/" "$HOME/Proyectos/shotbar/"
    if (cd "$HOME/Proyectos/shotbar" && cargo build --release); then
        install -m755 "$HOME/Proyectos/shotbar/target/release/shotbar" "$HOME/.local/bin/shotbar"
        ok "shotbar instalado"
    else
        aviso "shotbar no compiló; el resto funciona igual"
    fi
fi

# ---------------------------------------------------------------- sistema
if [ "$SISTEMA" = 1 ]; then
    azul "Ajustes del sistema"
    if pregunta "¿Poner el sistema en español (es_ES.UTF-8) y teclado español?"; then
        sudo sed -i 's/^#\s*\(es_ES.UTF-8 UTF-8\)/\1/; s/^#\s*\(en_US.UTF-8 UTF-8\)/\1/' /etc/locale.gen
        sudo locale-gen
        sudo localectl set-locale LANG=es_ES.UTF-8 LC_COLLATE=C || true
        sudo localectl set-keymap es || true
        sudo localectl set-x11-keymap es || true
        ok "Idioma y teclado"
    fi
    if pregunta "¿Inicio de sesión automático en tty1 que arranca Hyprland directamente?"; then
        sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
        printf '[Service]\nExecStart=\nExecStart=-/usr/bin/agetty --autologin %s --noclear %%I $TERM\n' "$USER" \
            | sudo tee /etc/systemd/system/getty@tty1.service.d/override.conf >/dev/null
        ok "Autologin para $USER (lo arranca ~/.bash_profile)"
    fi
    sudo systemctl enable NetworkManager.service >/dev/null 2>&1 || true
    sudo systemctl enable bluetooth.service >/dev/null 2>&1 || true
    if [ "$(basename "${SHELL:-}")" != "bash" ]; then
        pregunta "¿Usar bash como shell (la configuración es para bash)?" && chsh -s /usr/bin/bash || true
    fi
fi

# ---------------------------------------------------------------- final
echo
azul "¡Listo!"
cat <<EOF

   Reinicia (o entra en tty1) y arrancará Hyprland con todo:
   colores matugen, barra y dock Horizonte, el pingüino, SUPER+F1 para estilos.

   Pantallas: hypr/monitors.lua es el de la máquina original (Virtual-1, 1920x1200).
   Ajusta el tuyo con  nwg-displays  (está instalado).

   Lo que había antes está en: $BACKUP
   Para guardar cambios futuros en el repo:  $REPO/guardar.sh && git -C $REPO commit -am "..." && git -C $REPO push

EOF
