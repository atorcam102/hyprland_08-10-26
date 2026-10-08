-- Atajos de Albert (fila F), cargados desde keybinding.lua
-- Chuleta completa: SUPER + CTRL + K
local mainMod = "SUPER"
local S = "~/.config/hypr/scripts/"

-- Aspecto
hl.bind(mainMod .. " + F1",  hl.dsp.exec_cmd(S .. "estilo.sh"),            { description = "Cambiar estilo (horizonte / alberrtttt / radical / suave / clásico)" })
hl.bind(mainMod .. " + F2",  hl.dsp.exec_cmd(S .. "modo-foco.sh"),          { description = "Modo foco (sin huecos ni bordes)" })
hl.bind(mainMod .. " + F3",  hl.dsp.exec_cmd(S .. "luz-nocturna.sh"),       { description = "Luz nocturna" })
hl.bind(mainMod .. " + F7",  hl.dsp.exec_cmd(S .. "toggle-animations.sh"),  { description = "Activar/desactivar animaciones" })

-- Herramientas
hl.bind(mainMod .. " + F4",  hl.dsp.exec_cmd(S .. "color-picker.sh"),       { description = "Copiar un color de la pantalla" })
hl.bind(mainMod .. " + F5",  hl.dsp.exec_cmd(S .. "scratchpad.sh"),         { description = "Terminal desplegable" })
hl.bind(mainMod .. " + F6",  hl.dsp.exec_cmd(S .. "temporizador.sh"),       { description = "Temporizador rápido" })
hl.bind(mainMod .. " + F8",  hl.dsp.exec_cmd(S .. "apuntes.sh"),            { description = "Apunte rápido (escribe «ver» para abrirlos)" })
hl.bind(mainMod .. " + F9",  hl.dsp.exec_cmd(S .. "buscar.sh"),             { description = "Buscar en la web (yt / w / aur / gh)" })
hl.bind(mainMod .. " + F10", hl.dsp.exec_cmd(S .. "estado.sh"),             { description = "Cómo va la máquina" })
hl.bind(mainMod .. " + F12", hl.dsp.exec_cmd(S .. "bienvenida.sh"),         { description = "Saludo de Albert" })

-- Editar mi propia configuración
hl.bind(mainMod .. " + ALT + C", hl.dsp.exec_cmd("kitty --class flotante -e ${EDITOR:-nano} ~/.config/hypr/firma.lua"), { description = "Editar mi firma (colores y nombre)" })

-- Terminal desplegable
hl.window_rule({
    name = "scratchpad-terminal",
    match = { class = "^scratchpad$" },
    workspace = "special:scratch",
    float = true,
    center = true,
    size = "60% 50%",
})

-- Cualquier kitty lanzado con --class flotante sale flotando y centrado
hl.window_rule({
    name = "kitty-flotante",
    match = { class = "^flotante$" },
    float = true,
    center = true,
    size = "900 600",
})

-- Vídeo e imágenes siempre opacos y sin atenuar
hl.window_rule({
    name = "multimedia-opaca",
    match = { class = "^(mpv|vlc|imv|org.gnome.Loupe|com.github.rafostar.Clapper)$" },
    opacity = "1.0 override 1.0 override",
    no_dim = true,
})

-- Nada se atenúa ni se transparenta en pantalla completa
hl.window_rule({
    name = "pantalla-completa-opaca",
    match = { fullscreen = true },
    opacity = "1.0 override 1.0 override",
    no_dim = true,
})

-- Capturas con historial temporal (shotbar): clipboard + panel en la barra
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("shotbar region"), { description = "Captura de una zona (copiada + historial)" })
hl.bind("PRINT",                   hl.dsp.exec_cmd("shotbar region"), { description = "Captura de una zona (copiada + historial)" })
hl.bind("SHIFT + PRINT",           hl.dsp.exec_cmd("shotbar screen"), { description = "Captura de la pantalla completa" })
hl.bind("CTRL + PRINT",            hl.dsp.exec_cmd("shotbar window"), { description = "Captura de una ventana" })
hl.bind(mainMod .. " + ALT + P",   hl.dsp.exec_cmd("shotbar panel"),  { description = "Panel de capturas" })
-- Sin animación en la selección de slurp (si no, su borde sale en la captura)
hl.layer_rule({ match = { namespace = "selection" }, no_anim = true })
-- Panel de capturas: mismo cristal que la barra, sin animación de entrada
hl.layer_rule({ match = { namespace = "shotbar" }, blur = true, ignore_alpha = 0.5, no_anim = true })
hl.layer_rule({ match = { namespace = "shotbar-preview" }, no_anim = true })
