# shotbar

Capturas estilo macOS para Hyprland: seleccionas → se copia al portapapeles →
queda en un historial temporal (5 últimas) accesible desde la statusbar
Quickshell de ML4W, desde donde se arrastra a cualquier app.

## Uso

| Atajo | Acción |
|---|---|
| `Super+Shift+S` / `Impr` | zona (`shotbar region`) |
| `Shift+Impr` | monitor con el foco (`shotbar screen`) |
| `Ctrl+Impr` | ventana (`shotbar window`) |
| `Super+Alt+P` o clic en 󰹑 de la barra | panel (`shotbar panel`) |

En el panel: **arrastrar** una miniatura = soltarla como archivo PNG (Discord,
Telegram, Chrome/Slides, Nautilus…) · **clic** = copiar otra vez ·
**Espacio** con el ratón encima = verla en grande (rueda/pellizco: zoom,
arrastrar: mover, `0`: ajustar) · **clic derecho** = Copiar / Abrir /
Guardar en Imágenes / Eliminar · **Limpiar** · clic fuera o `Esc` = cerrar.

Otras órdenes: `shotbar clear | count | list | dir | preview [RUTA]`.

## Diseño

- **Historial = `$XDG_RUNTIME_DIR/shotbar/`** (tmpfs): se vacía solo al apagar.
  Sin índice aparte; miniaturas en `.thumbs/`. `flock` para capturas simultáneas.
- **Captura**: slurp (colores de matugen) → grim (`-l 1`, rápido) a un archivo
  temporal que se renombra → `wl-copy` → `qs ipc call shotbar captured`
  (contador + destello de 500 ms) → miniatura. Si la barra no responde, una
  notificación breve.
- **Barra**: `ScreenshotsModule.qml` (copia en `assets/`) registrado en
  `StatusbarWindow.qml` como `screenshots`; reutiliza los tokens de `Theme.qml`.
  Lee `shotbar count` al arrancar, así sobrevive a reinicios de la barra.
- **Panel**: GTK4 + gtk4-layer-shell, sin daemon (abre en ~80 ms con el
  renderizador cairo). Una única superficie Overlay a pantalla completa: los
  clics fuera de la tarjeta la cierran. Teclado exclusivo; durante un arrastre
  lo suelta y vacía su región de entrada, porque Hyprland encierra el puntero
  en la capa con teclado exclusivo y el destino no recibiría el drop.
- **Drag-and-drop**: `GtkDragSource` + `GdkContentProvider` union de
  `GdkFileList` (`text/uri-list`, portal de archivos para Flatpak) y
  `image/png`.

## Instalación

`scripts/install.sh` (comprueba paquetes con pacman, compila, instala en
`~/.local/bin`, integra barra y atajos con backups `*.backup-shotbar`).
