# hyprland_08-10-26

El escritorio Hyprland de **Albert (alberrtttt)** tal como estaba el 08/10/2026, listo para clonarlo en otro Arch Linux.

- **Hyprland** (configuración en Lua) sobre **ML4W 2.16**, rediseño **Horizonte**
- Colores generados por **matugen** a partir del fondo (o de la semilla ámbar en `ml4w/settings/color-seed`)
- Barra y dock de **Quickshell** (`ml4w-statusbar`, `ml4w-dock`), overview, swaync, rofi y wlogout
- **El pingüino** que camina sobre las ventanas (`~/.local/share/window-pet`)
- Estilos intercambiables con **SUPER+F1**: horizonte, alberrtttt, radical, suave y clásico
- `firma.lua`, con el borde degradado que sigue al fondo
- **shotbar**, la herramienta de capturas (se compila al instalar)
- Iconos **kora**, cursor **Bibata-Modern-Amber** y fuente **JetBrainsMono Nerd Font**
- Bash con `.bashrc_custom` (alias `firma`, `estilo`, `apunta`, …), oh-my-posh y fastfetch
- Sistema en español, teclado `es` y autologin en tty1 que arranca Hyprland

## Instalar en otra máquina

Parte de un Arch Linux base con un usuario que tenga `sudo` y conexión a internet:

```bash
sudo pacman -S --needed git
git clone https://github.com/atorcam102/hyprland_08-10-26.git
cd hyprland_08-10-26
./install.sh
```

Opciones: `--sin-paquetes` (solo copia la configuración), `--sin-sistema` (no toca el idioma, el teclado ni el autologin) y `--si` (no pregunta nada).

Antes de sobrescribir nada, el instalador mueve lo que ya hubiera a `~/.backup-antes-de-hyprland-<fecha>/`.

Después de instalar, configura las pantallas con `nwg-displays`: el `monitors.lua` guardado es el de la máquina virtual original (Virtual-1, 1920x1200).

## Guardar cambios futuros

```bash
./guardar.sh            # copia el estado actual al repo
git add -A && git commit -m "cambios" && git push
```

## Estructura

| Ruta | Qué es |
|---|---|
| `home/` | Se copia tal cual a `~` (dotfiles de ML4W, dock, barra, estilos, el pingüino, scripts) |
| `assets/icons.tar.gz` | Iconos kora y cursores Bibata |
| `proyectos/shotbar/` | Código de shotbar |
| `packages/` | Paquetes de pacman, AUR, flatpak y pipx |
| `system/dconf.ini` | Ajustes de GTK y GNOME (modo oscuro, cursor, fuente, iconos) |

No se guardan los navegadores, el historial, las claves ni los tokens.
