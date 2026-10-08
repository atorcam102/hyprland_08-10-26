--       _ _                 _   _   _   _
--  __ _| | |__  ___ _ _ _ _| |_| |_| |_| |_
-- / _` | | '_ \/ -_) '_| '_|  _|  _|  _|  _|
-- \__,_|_|_.__/\___|_| |_|  \__|\__|\__|\__|
--
-- La firma de Albert: todo lo que hace que este escritorio sea mío.
-- Cambia aquí los colores o el nombre y se aplica en todo el Hyprland
-- (bordes, sombras, bienvenida). Tras editar: SUPER + CTRL + R.

firma = {
    nombre = "Albert",
    alias  = "alberrtttt",

    -- Colores de la casa (hex sin #)
    violeta = "c792ea",
    cian    = "7fdbff",
    rosa    = "ff6ac1",
    noche   = "0f0b1a",

    -- true: el borde usa los colores del fondo de pantalla (siempre combina).
    -- false: usa violeta/cian/rosa fijos de arriba.
    seguir_fondo = true,

    -- El borde de la ventana activa gira despacio. Ponlo a false
    -- si notas que consume CPU (en máquina virtual, por ejemplo).
    bordes_giratorios = true,
}

-- rgba("c792ea", 0.5) -> "rgba(c792ea80)"
function firma.rgba(hex, alpha)
    return string.format("rgba(%s%02x)", hex, math.floor((alpha or 1) * 255 + 0.5))
end

-- Colores del borde activo según seguir_fondo
function firma.borde()
    if firma.seguir_fondo then
        return { primary, tertiary, secondary }
    end
    return { firma.rgba(firma.violeta), firma.rgba(firma.cian), firma.rgba(firma.rosa) }
end
